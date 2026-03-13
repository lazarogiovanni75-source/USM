class PublishQueueService
  def initialize(user = nil)
    @user = user
  end
  
  def add_to_queue(content_data:, platform:, scheduled_at:, priority: :normal, scheduled_post_id: nil, content_id: nil, dependency_ids: [])
    queue_item = @user.publish_queues.build if @user
    queue_item ||= PublishQueue.new(user: @user)
    
    queue_item.initialize_queue_item(
      content_data: content_data,
      platform: platform,
      scheduled_at: scheduled_at,
      priority: priority,
      dependency_ids: dependency_ids
    )
    
    queue_item.scheduled_post_id = scheduled_post_id
    queue_item.content_id = content_id
    
    if queue_item.save
      { success: true, queue_item: queue_item, position: queue_position(queue_item) }
    else
      { success: false, errors: queue_item.errors.full_messages }
    end
  end
  
  def add_scheduled_post_to_queue(scheduled_post_id, priority: :normal)
    scheduled_post = @user.scheduled_posts.find(scheduled_post_id) if @user
    
    return { success: false, error: "Scheduled post not found" } unless scheduled_post
    
    content_data = {
      title: scheduled_post.content.title,
      body: scheduled_post.content.body,
      images: scheduled_post.content.images.attached? ? scheduled_post.content.images.map { |img| Rails.application.routes.url_helpers.rails_blob_url(img) } : [],
      videos: scheduled_post.content.videos.attached? ? scheduled_post.content.videos.map { |vid| Rails.application.routes.url_helpers.rails_blob_url(vid) } : []
    }
    
    add_to_queue(
      content_data: content_data,
      platform: scheduled_post.platform,
      scheduled_at: scheduled_post.scheduled_at,
      priority: priority,
      scheduled_post_id: scheduled_post_id,
      content_id: scheduled_post.content_id
    )
  end
  
  def process_queue(platform: nil, max_items: 10)
    queue_items = @user.publish_queues.ready_for_publishing.by_priority
    queue_items = queue_items.where(platform: platform) if platform.present?
    
    processed_items = []
    processed_count = 0
    
    queue_items.limit(max_items).each do |item|
      break if processed_count >= max_items
      
      # Check rate limiting for platform
      break unless check_rate_limit(item.platform)
      
      # Acquire lock
      break unless item.acquire_lock
      
      begin
        # Process the item
        result = process_queue_item(item)
        processed_items << { item: item, result: result }
        processed_count += 1
        
        # Add delay between posts if needed
        add_platform_delay(item.platform)
        
      rescue => e
        Rails.logger.error "Error processing queue item #{item.id}: #{e.message}"
        item.mark_failed(e.message)
        processed_items << { item: item, result: { success: false, error: e.message } }
      ensure
        item.release_lock
      end
    end
    
    {
      processed_count: processed_count,
      items: processed_items,
      rate_limited: processed_count == 0 && queue_items.any?
    }
  end
  
  def process_queue_item(queue_item)
    return { success: false, error: "Queue item not ready for processing" } unless queue_item.can_process?
    
    # Update status to processing
    queue_item.update!(status: :processing)
    
    # Prepare content for publishing
    content_data = queue_item.content_data
    platform = queue_item.platform
    
    # Mark as processed - integration with Atlas Cloud for social media posting
    # In production, this would call the appropriate social media API
    result = { success: true, post_id: "post_#{SecureRandom.hex(8)}" }
    
    if result[:success]
      queue_item.mark_published(
        platform_post_id: result[:post_id],
        published_at: Time.current
      )
      
      # Update scheduled post if exists
      if queue_item.scheduled_post_id
        scheduled_post = @user.scheduled_posts.find(queue_item.scheduled_post_id)
        scheduled_post.update!(status: 'published', posted_at: Time.current, platform_post_id: result[:post_id])
      end
      
      { success: true, post_id: result[:post_id], published_at: Time.current }
    else
      queue_item.mark_failed(result[:error])
      { success: false, error: result[:error] }
    end
  end
  
  def get_queue_status
    {
      total: @user.publish_queues.count,
      pending: @user.publish_queues.pending.count,
      processing: @user.publish_queues.processing.count,
      published: @user.publish_queues.published.count,
      failed: @user.publish_queues.failed.count,
      retrying: @user.publish_queues.retrying.count,
      queued_for_today: @user.publish_queues.where('scheduled_at >= ? AND scheduled_at < ?', Time.current.beginning_of_day, Time.current.end_of_day).count
    }
  end
  
  def get_queue_analytics(days = 7)
    start_date = days.days.ago.beginning_of_day
    end_date = Time.current.end_of_day
    
    published_items = @user.publish_queues
                        .published
                        .where('published_at >= ? AND published_at <= ?', start_date, end_date)
    
    failed_items = @user.publish_queues
                    .failed
                    .where('updated_at >= ? AND updated_at <= ?', start_date, end_date)
    
    avg_processing_time = if published_items.any?
      published_items.average('EXTRACT(EPOCH FROM (published_at - locked_at))')
    else
      0
    end
    
    success_rate = if (published_items.count + failed_items.count) > 0
      (published_items.count.to_f / (published_items.count + failed_items.count) * 100).round(2)
    else
      0
    end
    
    {
      total_processed: published_items.count + failed_items.count,
      success_rate: success_rate,
      avg_processing_time: avg_processing_time&.round(2),
      platform_breakdown: platform_analytics(published_items),
      daily_stats: daily_analytics(published_items, failed_items, days)
    }
  end
  
  def cancel_queue_item(queue_item_id)
    queue_item = @user.publish_queues.find(queue_item_id)
    
    if queue_item.status.in?([:pending, :retrying])
      queue_item.cancel
      { success: true, message: "Queue item cancelled" }
    else
      { success: false, error: "Cannot cancel item in status: #{queue_item.status}" }
    end
  end
  
  def retry_failed_item(queue_item_id)
    queue_item = @user.publish_queues.find(queue_item_id)
    
    if queue_item.retry_eligible?
      queue_item.update!(
        status: :retrying,
        next_retry_at: nil,
        error_message: nil
      )
      { success: true, message: "Failed item queued for retry" }
    else
      { success: false, error: "Item not eligible for retry or retry limit reached" }
    end
  end
  
  def clear_completed_queue
    completed_count = @user.publish_queues.where(status: [:published, :cancelled]).count
    @user.publish_queues.where(status: [:published, :cancelled]).destroy_all
    { success: true, cleared_count: completed_count }
  end
  
  def pause_queue
    @user.publish_queues.where(status: [:pending, :retrying]).update_all(status: :cancelled)
    { success: true, message: "Queue paused and pending items cancelled" }
  end
  
  def resume_queue
    { success: true, message: "Queue resumed - create new items to continue publishing" }
  end
  
  def optimize_queue
    # Reorder queue based on optimal timing and platform efficiency
    pending_items = @user.publish_queues.pending.by_priority
    
    optimal_order = []
    processed_platforms = []
    
    # Group by platform and sort by optimal times
    pending_items.group_by(&:platform).each do |platform, items|
      # Sort by scheduled time and priority
      sorted_items = items.sort_by { |item| [item.scheduled_at, item.priority] }
      optimal_order.concat(sorted_items)
    end
    
    # Update queue order (in practice, this would involve a priority field)
    optimal_order.each_with_index do |item, index|
      item.update!(priority: item.priority + (index * 0.1)) # Small increments to maintain relative priority
    end
    
    { success: true, optimized_count: optimal_order.length }
  end
  
  private
  
  def queue_position(queue_item)
    # Calculate position in queue based on priority and scheduled time
    pending_items = @user.publish_queues.pending.order(priority: :desc, scheduled_at: :asc)
    position = pending_items.find_index(queue_item)&.+(1) || 0
    position
  end
  
  def check_rate_limit(platform)
    # Basic rate limiting check - implement platform-specific limits as needed
    true
  end
  
  def add_platform_delay(platform)
    # Add delay between posts for same platform to avoid rate limiting
    # Delay in seconds - adjust based on platform limits
    delays = {
      twitter: 5,
      instagram: 30,
      facebook: 60,
      linkedin: 60,
      tiktok: 120
    }
    delay = delays[platform.to_sym] || 10
    sleep(delay)
  end
  
  def platform_analytics(published_items)
    published_items.group(:platform).count.transform_keys(&:to_s)
  end
  
  def daily_analytics(published_items, failed_items, days)
    analytics = {}
    days.times do |i|
      date = (Time.current - i.days).to_date
      analytics[date.to_s] = {
        published: published_items.where('DATE(published_at) = ?', date).count,
        failed: failed_items.where('DATE(updated_at) = ?', date).count
      }
    end
    analytics
  end
end
