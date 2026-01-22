class ScheduledPostsController < ApplicationController
  before_action :set_scheduled_post, only: %i[show edit update destroy]
  before_action :authenticate_user!

  # GET /scheduled_posts
  def index
    @scheduled_posts = current_user.scheduled_posts.includes(:content).order(scheduled_at: :asc)
    @upcoming_posts = @scheduled_posts.where('scheduled_at >= ?', Time.current)
    @past_posts = @scheduled_posts.where('scheduled_at < ?', Time.current)
    
    # Calendar view data
    @calendar_posts = @scheduled_posts.group_by { |post| post.scheduled_at.to_date }
    
    # Statistics
    @total_scheduled = @scheduled_posts.count
    @today_posts = @scheduled_posts.where(scheduled_at: Time.current.beginning_of_day..Time.current.end_of_day).count
    @this_week_posts = @scheduled_posts.where(scheduled_at: Time.current.beginning_of_week..Time.current.end_of_week).count
  end

  # GET /scheduled_posts/1
  def show
    @related_posts = current_user.scheduled_posts.where(content_id: @scheduled_post.content_id).where.not(id: @scheduled_post.id).limit(5)
  end

  # GET /scheduled_posts/new
  def new
    @scheduled_post = current_user.scheduled_posts.build
    @available_content = current_user.contents.where(status: 'approved')
  end

  # GET /scheduled_posts/1/edit
  def edit
    @available_content = current_user.contents.where(status: 'approved')
  end

  # POST /scheduled_posts
  def create
    @scheduled_post = current_user.scheduled_posts.build(scheduled_post_params)
    @available_content = current_user.contents.where(status: 'approved')

    if @scheduled_post.save
      # Calculate optimal posting time if not specified
      if params[:optimize_timing].present?
        optimal_time = SchedulerService.new.calculate_optimal_time(
          @scheduled_post.content.platform,
          @scheduled_post.content.campaign&.target_audience
        )
        @scheduled_post.update!(scheduled_at: optimal_time)
      end
      
      redirect_to scheduled_post_path(@scheduled_post), notice: 'Post was successfully scheduled.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /scheduled_posts/1
  def update
    if @scheduled_post.update(scheduled_post_params)
      redirect_to scheduled_post_path(@scheduled_post), notice: 'Scheduled post was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /scheduled_posts/1
  def destroy
    @scheduled_post.destroy
    redirect_to scheduled_posts_url, notice: 'Scheduled post was successfully deleted.'
  end

  # Bulk operations
  def bulk_update
    post_ids = params[:post_ids]
    action = params[:action_type]
    
    posts = current_user.scheduled_posts.where(id: post_ids)
    updated_count = 0
    
    case action
    when 'publish_now'
      posts.each do |post|
        if post.update(status: 'published', posted_at: Time.current)
          MakeaiService.new(post).publish_to_platform
          updated_count += 1
        end
      end
      message = "Successfully published #{updated_count} posts."
    when 'reschedule'
      new_time = DateTime.parse(params[:new_time])
      posts.each do |post|
        if post.update(scheduled_at: new_time)
          updated_count += 1
        end
      end
      message = "Successfully rescheduled #{updated_count} posts."
    when 'cancel'
      posts.each do |post|
        if post.update(status: 'cancelled')
          updated_count += 1
        end
      end
      message = "Successfully cancelled #{updated_count} scheduled posts."
    end
    
    redirect_to scheduled_posts_path, notice: message
  end

  # Drag and drop reschedule
  def reschedule
    post_id = params[:post_id]
    new_time = DateTime.parse(params[:new_time])
    
    post = current_user.scheduled_posts.find(post_id)
    if post.update(scheduled_at: new_time)
      render 'reschedule', formats: :turbo_stream
    else
      render 'reschedule_error', formats: :turbo_stream, status: :unprocessable_entity
    end
  end

  # Calendar view
  def calendar
    @selected_date = params[:date] ? Date.parse(params[:date]) : Date.current
    @posts_for_date = current_user.scheduled_posts.where(scheduled_at: @selected_date.beginning_of_day..@selected_date.end_of_day)
    
    render 'calendar'
  end

  # Get optimal posting times
  def optimal_times
    platform = params[:platform]
    audience = params[:audience]
    
    optimal_times = SchedulerService.new.calculate_optimal_times(platform, audience)
    render 'optimal_times', formats: :turbo_stream
  end

  # Preview scheduling impact
  def preview_scheduling
    post_ids = params[:post_ids]
    new_time = DateTime.parse(params[:new_time])
    
    impact_analysis = SchedulerService.new.analyze_scheduling_impact(post_ids, new_time)
    render 'scheduling_impact', formats: :turbo_stream
  end

  # Analytics for scheduling performance
  def scheduling_analytics
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : 30.days.ago.to_date
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.current
    
    @scheduled_posts = current_user.scheduled_posts.where(scheduled_at: @start_date.beginning_of_day..@end_date.end_of_day)
    
    # Calculate metrics
    @posts_by_day = @scheduled_posts.group("DATE(scheduled_at)").count
    @posts_by_platform = @scheduled_posts.group(:platform).count
    @success_rate = (@scheduled_posts.where(status: 'published').count.to_f / @scheduled_posts.count * 100).round(2)
    
    render 'analytics'
  end

  private
    def set_scheduled_post
      @scheduled_post = current_user.scheduled_posts.find(params[:id])
    end

    def scheduled_post_params
      params.require(:scheduled_post).permit(:content_id, :social_account_id, :scheduled_at, :status, :posted_at)
    end
end