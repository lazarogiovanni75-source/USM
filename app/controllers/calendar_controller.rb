class CalendarController < ApplicationController
  before_action :authenticate_user!
  before_action :set_current_month, only: [:index]

  def index
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    @current_view = params[:view] || 'month'
    @start_date = @date.beginning_of_month.beginning_of_week
    @end_date = @date.end_of_month.end_of_week
    
    # Get all content for the month
    @scheduled_posts = current_user.scheduled_posts
      .where('scheduled_at >= ? AND scheduled_at <= ?', @start_date, @end_date)
      .includes(:content)
      .order(:scheduled_at)
    
    @drafts = current_user.draft_contents
      .where('created_at >= ? AND created_at <= ?', @start_date, @end_date)
      .order(:updated_at)
    
    @contents = current_user.contents
      .where('published_at >= ? AND published_at <= ?', @start_date, @end_date)
      .order(:published_at)
    
    # Get optimal posting times
    @optimal_times = CalendarService.suggest_optimal_times(current_user, @date)
    
    # Get content gaps
    @content_gaps = CalendarService.analyze_content_gaps(current_user, @start_date..@end_date)
    
    # Set current date for navigation
    @current_date = @date
  end

  def schedule_post
    @post = current_user.scheduled_posts.find(params[:id])
    new_date = Date.parse(params[:new_date])
    new_time = Time.parse("#{params[:new_time]}:00")
    
    @post.update!(scheduled_at: new_date.to_datetime.change(hour: new_time.hour, minute: new_time.minute))
    
    @success = true
  rescue => e
    @error = e.message
    @success = false
  end

  def quick_schedule
    content = params[:content]
    date = Date.parse(params[:date])
    time = Time.parse(params[:time])
    
    scheduled_post = current_user.scheduled_posts.create!(
      content: content,
      scheduled_at: date.to_datetime.change(hour: time.hour, minute: time.minute),
      status: 'scheduled'
    )
    
    @date = date
    @scheduled_post = scheduled_post
  end

  def month_view
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    @start_date = @date.beginning_of_month.beginning_of_week
    @end_date = @date.end_of_month.end_of_week
    
    @scheduled_posts = current_user.scheduled_posts
      .where('scheduled_at >= ? AND scheduled_at <= ?', @start_date, @end_date)
      .includes(:content)
      .order(:scheduled_at)
  end

  def week_view
    @start_date = params[:date] ? Date.parse(params[:date]).beginning_of_week : Date.current.beginning_of_week
    @end_date = @start_date + 6.days
    
    @scheduled_posts = current_user.scheduled_posts
      .where('scheduled_at >= ? AND scheduled_at <= ?', @start_date, @end_date)
      .includes(:content)
      .order(:scheduled_at)
  end

  def day_view
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    @start_time = @date.beginning_of_day
    @end_time = @date.end_of_day
    
    @scheduled_posts = current_user.scheduled_posts
      .where('scheduled_at >= ? AND scheduled_at <= ?', @start_time, @end_time)
      .includes(:content)
      .order(:scheduled_at)
    
    @available_slots = generate_available_slots(@date)
  end

  def create_content_slots
    date = Date.parse(params[:date])
    platform = params[:platform] || 'all'
    
    @slots = []
    6.times do |i|
      @slots << {
        time: date.beginning_of_day + (i * 4).hours + 12.hours,
        suggested: true,
        engagement_prediction: rand(0.7..0.9).round(2)
      }
    end
  end

  def platform_overview
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    @start_date = @date.beginning_of_month
    @end_date = @date.end_of_month
    
    @platform_stats = current_user.scheduled_posts
      .where('scheduled_at >= ? AND scheduled_at <= ?', @start_date, @end_date)
      .group(:platform)
      .count
  end

  def analytics_view
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    @start_date = @date.beginning_of_month
    @end_date = @date.end_of_month
    
    @analytics = {
      total_posts: current_user.scheduled_posts.where('scheduled_at >= ? AND scheduled_at <= ?', @start_date, @end_date).count,
      scheduled_posts: current_user.scheduled_posts.where('scheduled_at >= ? AND scheduled_at <= ?', @start_date, @end_date, status: 'scheduled').count,
      published_posts: current_user.scheduled_posts.where('scheduled_at >= ? AND scheduled_at <= ?', @start_date, @end_date, status: 'published').count,
      pending_posts: current_user.scheduled_posts.where('scheduled_at >= ? AND scheduled_at <= ?', @start_date, @end_date, status: 'pending').count
    }
  end

  def optimize
    # Optimize the schedule based on engagement predictions
    @optimized_count = 0
    
    # Get posts that can be optimized (scheduled but not yet published)
    posts = current_user.scheduled_posts.where(status: 'scheduled')
    
    # For now, just return success - in production this would use AI optimization
    posts.each do |post|
      # Simple optimization: suggest better times based on platform
      best_time = suggest_best_time(post.platform, post.scheduled_at)
      if best_time != post.scheduled_at
        post.update!(scheduled_at: best_time)
        @optimized_count += 1
      end
    end
    
    # Use Turbo Stream for redirect
    redirect_to calendar_path, notice: "Optimized #{@optimized_count} posts"
  rescue => e
    redirect_to calendar_path, alert: "Optimization failed: #{e.message}"
  end

  # Edit scheduled post
  def edit_post
    @post = current_user.scheduled_posts.find(params[:id])
    
    if request.format turbo_stream?
      render 'edit_post', formats: :turbo_stream
    end
  end

  # Update scheduled post
  def update_post
    @post = current_user.scheduled_posts.find(params[:id])
    
    unless @post.can_edit?
      redirect_to calendar_path, alert: 'This post can no longer be edited'
      return
    end
    
    if @post.update(post_params)
      if request.format turbo_stream?
        render 'update_post', formats: :turbo_stream
      else
        redirect_to calendar_path, notice: 'Post updated successfully'
      end
    else
      if request.format turbo_stream?
        render 'edit_post_error', formats: :turbo_stream, status: :unprocessable_entity
      else
        redirect_to calendar_path, alert: @post.errors.full_messages.join(', ')
      end
    end
  end

  # Cancel scheduled post
  def cancel_post
    @post = current_user.scheduled_posts.find(params[:id])
    
    unless @post.can_cancel?
      redirect_to calendar_path, alert: 'This post cannot be cancelled'
      return
    end
    
    @post.update!(status: :cancelled)
    
    if request.format turbo_stream?
      render 'cancel_post', formats: :turbo_stream
    else
      redirect_to calendar_path, notice: 'Post cancelled successfully'
    end
  rescue => e
    redirect_to calendar_path, alert: "Failed to cancel post: #{e.message}"
  end

  # Retry failed post
  def retry_post
    @post = current_user.scheduled_posts.find(params[:id])
    
    unless @post.can_retry?
      redirect_to calendar_path, alert: 'This post cannot be retried'
      return
    end
    
    @post.update!(status: :scheduled, error_message: nil)
    
    # Re-enqueue for publishing
    SocialMediaAgentWorker.perform_async({ post_id: @post.id })
    
    if request.format turbo_stream?
      render 'retry_post', formats: :turbo_stream
    else
      redirect_to calendar_path, notice: 'Post has been requeued for publishing'
    end
  rescue => e
    redirect_to calendar_path, alert: "Failed to retry post: #{e.message}"
  end

  # Publish post immediately
  def publish_now
    @post = current_user.scheduled_posts.find(params[:id])
    
    if @post.status == :published
      redirect_to calendar_path, alert: 'This post has already been published'
      return
    end
    
    unless @post.has_assets?
      redirect_to calendar_path, alert: 'This post needs assets before it can be published'
      return
    end
    
    # Queue for immediate publishing
    SocialMediaAgentWorker.perform_async({ post_id: @post.id })
    
    if request.format turbo_stream?
      render 'publish_now', formats: :turbo_stream
    else
      redirect_to calendar_path, notice: 'Post is being published...'
    end
  rescue => e
    redirect_to calendar_path, alert: "Failed to publish post: #{e.message}"
  end

  # Get post details for modal - redirect to show_post
  def post_details
    @post = current_user.scheduled_posts.includes(:content, :social_account).find(params[:id])
    
    render 'calendar/show_post'
  end

  # Show post details page
  def show_post
    @post = current_user.scheduled_posts.includes(:content, :social_account).find(params[:id])
    
    render 'calendar/show_post'
  end

  # Bulk cancel posts
  def bulk_cancel
    post_ids = params[:post_ids]
    
    return redirect_to(calendar_path, alert: 'No posts selected') unless post_ids.present?
    
    posts = current_user.scheduled_posts.where(id: post_ids).where(status: %w[draft scheduled])
    count = posts.update_all(status: :cancelled)
    
    redirect_to calendar_path, notice: "#{count} posts cancelled successfully"
  rescue => e
    redirect_to calendar_path, alert: "Failed to cancel posts: #{e.message}"
  end

  # Bulk reschedule posts
  def bulk_reschedule
    post_ids = params[:post_ids]
    new_date = Date.parse(params[:new_date])
    new_time = Time.parse(params[:new_time])
    
    return redirect_to(calendar_path, alert: 'No posts selected') unless post_ids.present?
    
    posts = current_user.scheduled_posts.where(id: post_ids).where(status: %w[draft scheduled])
    new_datetime = new_date.to_datetime.change(hour: new_time.hour, min: new_time.min)
    count = posts.update_all(scheduled_at: new_datetime)
    
    redirect_to calendar_path, notice: "#{count} posts rescheduled successfully"
  rescue => e
    redirect_to calendar_path, alert: "Failed to reschedule posts: #{e.message}"
  end

  def suggestions
    # Get AI-powered content suggestions for the calendar
    @suggestions = CalendarService.generate_weekly_content_ideas(current_user, Date.current.beginning_of_week)
    
    # Render using Turbo Stream
    render "calendar/suggestions", layout: false
  end

  def suggest_best_time(platform, current_time)
    # Suggest better time based on platform best times
    best_times = {
      'instagram' => [9, 11, 14, 17],
      'twitter' => [8, 12, 18, 21],
      'linkedin' => [8, 9, 12, 17],
      'facebook' => [13, 15, 19, 21],
      'tiktok' => [6, 10, 19, 20]
    }
    
    platform_best = best_times[platform.to.downcase] || best_times['instagram']
    current_hour = current_time.hour
    
    # Find closest best time
    closest = platform_best.min_by { |t| (t - current_hour).abs }
    
    current_time.change(hour: closest)
  end

  private

  def set_current_month
    @current_month = params[:month] || Date.current.month
    @current_year = params[:year] || Date.current.year
  end

  def post_params
    params.require(:scheduled_post).permit(
      :scheduled_at,
      :content_id,
      :social_account_id,
      :status,
      :image_url,
      :video_url,
      :asset_url,
      target_platforms: []
    )
  end

  def generate_available_slots(date)
    slots = []
    
    # Generate slots every 2 hours from 8am to 8pm
    6.times do |i|
      slots << {
        time: date.beginning_of_day + (8 + i * 2).hours,
        available: true,
        posts_count: current_user.scheduled_posts.where('scheduled_at >= ? AND scheduled_at < ?', 
          date.beginning_of_day + (8 + i * 2).hours, 
          date.beginning_of_day + (8 + i * 2 + 2).hours
        ).count
      }
    end
    
    slots
  end
end