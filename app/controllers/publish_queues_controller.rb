class PublishQueuesController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @publish_queues = current_user.publish_queues
                                 .includes(:scheduled_post, :content)
                                 .order(created_at: :desc)
    
    @queue_service = PublishQueueService.new(current_user)
    @queue_status = @queue_service.get_queue_status
    @queue_analytics = @queue_service.get_queue_analytics
  end
  
  def show
    @queue_item = current_user.publish_queues.find(params[:id])
  end
  
  def new
    @publish_queue = PublishQueue.new
    
    # Get available scheduled posts and content
    @scheduled_posts = current_user.scheduled_posts
                                 .includes(:content)
                                 .where(status: 'scheduled')
                                 .order(scheduled_at: :asc)
    
    @contents = current_user.contents.order(created_at: :desc).limit(50)
  end
  
  def create
    @queue_service = PublishQueueService.new(current_user)
    
    result = if params[:scheduled_post_id].present?
      @queue_service.add_scheduled_post_to_queue(
        params[:scheduled_post_id],
        priority: params[:priority]&.to_sym || :normal
      )
    else
      content_data = {
        title: params[:title],
        body: params[:body],
        images: params[:images]&.split(',') || [],
        videos: params[:videos]&.split(',') || []
      }
      
      @queue_service.add_to_queue(
        content_data: content_data,
        platform: params[:platform],
        scheduled_at: Time.zone.parse("#{params[:scheduled_date]} #{params[:scheduled_time]}"),
        priority: params[:priority]&.to_sym || :normal,
        content_id: params[:content_id]
      )
    end
    
    if result[:success]
      redirect_to publish_queues_path, notice: "Successfully added to queue"
    else
      @scheduled_posts = current_user.scheduled_posts.includes(:content).where(status: 'scheduled')
      @contents = current_user.contents.order(created_at: :desc).limit(50)
      flash[:alert] = result[:errors]&.join(', ') || result[:error]
      render :new
    end
  end
  
  def edit
    @queue_item = current_user.publish_queues.find(params[:id])
    
    unless @queue_item.status.in?([:pending, :retrying])
      redirect_to publish_queues_path, alert: "Cannot edit queue item in status: #{@queue_item.status}"
    end
  end
  
  def update
    @queue_item = current_user.publish_queues.find(params[:id])
    
    if @queue_item.update(queue_params)
      redirect_to publish_queues_path, notice: "Queue item updated successfully"
    else
      flash[:alert] = @queue_item.errors.full_messages.join(', ')
      render :edit
    end
  end
  
  def destroy
    @queue_item = current_user.publish_queues.find(params[:id])
    
    if @queue_item.status.in?([:pending, :retrying])
      @queue_item.cancel
      redirect_to publish_queues_path, notice: "Queue item cancelled"
    else
      redirect_to publish_queues_path, alert: "Cannot cancel queue item in status: #{@queue_item.status}"
    end
  end
  
  def process
    @queue_service = PublishQueueService.new(current_user)
    result = @queue_service.process_queue(
      platform: params[:platform],
      max_items: params[:max_items]&.to_i || 5
    )
    
    if result[:rate_limited]
      redirect_to publish_queues_path, alert: "Rate limited. Please wait before processing more items."
    else
      redirect_to publish_queues_path, notice: "Processed #{result[:processed_count]} items from queue"
    end
  end
  
  def cancel_item
    @queue_service = PublishQueueService.new(current_user)
    result = @queue_service.cancel_queue_item(params[:id])
    
    if result[:success]
      redirect_to publish_queues_path, notice: result[:message]
    else
      redirect_to publish_queues_path, alert: result[:error]
    end
  end
  
  def retry_item
    @queue_service = PublishQueueService.new(current_user)
    result = @queue_service.retry_failed_item(params[:id])
    
    if result[:success]
      redirect_to publish_queues_path, notice: result[:message]
    else
      redirect_to publish_queues_path, alert: result[:error]
    end
  end
  
  def clear_completed
    @queue_service = PublishQueueService.new(current_user)
    result = @queue_service.clear_completed_queue
    
    redirect_to publish_queues_path, notice: "Cleared #{result[:cleared_count]} completed items"
  end
  
  def pause_queue
    @queue_service = PublishQueueService.new(current_user)
    result = @queue_service.pause_queue
    
    redirect_to publish_queues_path, notice: result[:message]
  end
  
  def resume_queue
    @queue_service = PublishQueueService.new(current_user)
    result = @queue_service.resume_queue
    
    redirect_to publish_queues_path, notice: result[:message]
  end
  
  def optimize_queue
    @queue_service = PublishQueueService.new(current_user)
    result = @queue_service.optimize_queue
    
    redirect_to publish_queues_path, notice: "Optimized #{result[:optimized_count]} queue items"
  end
  
  def queue_status
    @queue_service = PublishQueueService.new(current_user)
    @queue_status = @queue_service.get_queue_status
  end
  
  def queue_analytics
    @queue_service = PublishQueueService.new(current_user)
    @queue_analytics = @queue_service.get_queue_analytics(params[:days]&.to_i || 7)
  end
  
  private
  
  def queue_params
    params.require(:publish_queue).permit(:priority, :scheduled_at, :platform)
  end
end