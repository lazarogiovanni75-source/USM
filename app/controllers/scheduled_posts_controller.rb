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
      # Calculate optimal posting time if requested
      if params[:optimize_timing].present?
        scheduler = SchedulerService.new(current_user)
        optimal_time = scheduler.calculate_optimal_time(
          @scheduled_post.content.platform,
          @scheduled_post.content.campaign&.target_audience
        )
        @scheduled_post.update!(scheduled_at: optimal_time)
      end
      
      # Trigger automation for scheduled post
      trigger_automation('post_scheduled', @scheduled_post)
      
      # Track onboarding progress for first scheduled post
      current_user.complete_onboarding_step!(:schedule_post) if current_user.scheduled_posts.count == 1
      
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
    trigger_automation('post_cancelled', @scheduled_post)
    redirect_to scheduled_posts_url, notice: 'Scheduled post was successfully deleted.'
  end

  # Bulk operations
  def bulk_update
    post_ids = params[:post_ids]&.split(',')&.map(&:strip)
    action = params[:action_type]
    
    posts = current_user.scheduled_posts.where(id: post_ids)
    updated_count = 0
    
    case action
    when 'publish_now'
      posts.each do |post|
        if post.update(status: 'published', posted_at: Time.current)
          # Post published - ready for social media sharing
          updated_count += 1
        end
      end
      message = "Successfully published #{updated_count} posts."
    when 'reschedule'
      new_time = DateTime.parse(params[:new_time])
      scheduler = SchedulerService.new(current_user)
      
      posts.each do |post|
        # Use conflict resolution for bulk rescheduling
        result = scheduler.reschedule_with_conflicts_resolution(post.id, new_time)
        updated_count += 1 if result[:success]
      end
      message = "Successfully rescheduled #{updated_count} posts."
    when 'cancel'
      posts.each do |post|
        if post.update(status: 'cancelled')
          updated_count += 1
        end
      end
      message = "Successfully cancelled #{updated_count} scheduled posts."
    when 'optimize'
      scheduler = SchedulerService.new(current_user)
      optimization_results = scheduler.batch_schedule_optimization(post_ids)
      
      if optimization_results.any?
        # Apply optimizations
        optimization_results.each do |opt_result|
          post = current_user.scheduled_posts.find(opt_result[:post_id])
          post.update!(scheduled_at: opt_result[:suggested_time])
          updated_count += 1
        end
        message = "Successfully optimized #{updated_count} posts for better engagement."
      else
        message = "No optimization opportunities found."
      end
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
    
    render 'scheduled_posts/calendar'
  end

  # Get optimal posting times
  def optimal_times
    platform = params[:platform]
    audience = params[:audience]
    
    @scheduler = SchedulerService.new(current_user)
    @optimal_times = @scheduler.calculate_optimal_times(platform, audience)
  end

  # Batch scheduling with optimization
  def batch_schedule
    posts_data = JSON.parse(params[:posts_data] || '[]')
    platform = params[:platform]
    
    @scheduler = SchedulerService.new(current_user)
    @suggested_schedule = @scheduler.suggest_schedule_batch(posts_data, platform)
  end

  # Schedule optimization
  def optimize_schedule
    scheduler = SchedulerService.new(current_user)
    optimization_results = scheduler.batch_schedule_optimization(params[:post_ids])
    
    if optimization_results.any?
      optimization_results.each do |opt_result|
        post = current_user.scheduled_posts.find(opt_result[:post_id])
        post.update!(scheduled_at: opt_result[:suggested_time])
      end
      flash[:notice] = "Successfully optimized #{optimization_results.length} posts for better engagement."
    else
      flash[:alert] = "No optimization opportunities found."
    end
    redirect_to scheduled_posts_path
  end

  # Add note/comment to a scheduled post
  def add_note
    @scheduled_post = current_user.scheduled_posts.find(params[:id])
    
    if params[:internal_note].present?
      @scheduled_post.update(internal_note: params[:internal_note])
      flash[:notice] = "Note added successfully."
    else
      flash[:alert] = "Please enter a note."
    end
    
    redirect_to dashboards_path(anchor: 'comments-section'), notice: flash[:notice]
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboards_path, alert: "Post not found."
  end

  # Preview scheduling impact
  def preview_scheduling
    post_ids = params[:post_ids]&.split(',')&.map(&:strip)
    new_time = DateTime.parse(params[:new_time])
    
    @scheduler = SchedulerService.new(current_user)
    @impact_analysis = @scheduler.analyze_scheduling_impact(post_ids, new_time)
  end

  # Platform engagement predictions
  def engagement_predictions
    post_ids = params[:post_ids]&.split(',')&.map(&:strip)
    posts = current_user.scheduled_posts.where(id: post_ids)
    
    @scheduler = SchedulerService.new(current_user)
    predictions = []
    
    posts.each do |post|
      score = @scheduler.calculate_platform_engagement_score(post.platform, post.scheduled_at)
      predictions << {
        post_id: post.id,
        platform: post.platform,
        scheduled_time: post.scheduled_at,
        engagement_score: score,
        recommendations: generate_engagement_recommendations(post, score)
      }
    end
    
    @predictions = predictions
  end

  private

  def generate_engagement_recommendations(post, score)
    recommendations = []
    
    if score < 0.6
      recommendations << "Consider scheduling at peak hours for #{post.platform}"
    end
    
    if post.scheduled_at.saturday? || post.scheduled_at.sunday?
      if post.platform == 'linkedin'
        recommendations << "LinkedIn engagement is lower on weekends"
      else
        recommendations << "Weekend posting may perform well for #{post.platform}"
      end
    end
    
    if post.scheduled_at.hour < 6 || post.scheduled_at.hour > 22
      recommendations << "Consider scheduling during business hours"
    end
    
    recommendations
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
    
    # Enhanced analytics with scheduling insights
    scheduler = SchedulerService.new(current_user)
    @engagement_scores = {}
    
    @posts_by_platform.each do |platform, count|
      # Calculate average engagement score for this platform
      platform_posts = @scheduled_posts.where(platform: platform[0]) # platform is array [platform, count]
      total_score = platform_posts.sum do |post|
        scheduler.calculate_platform_engagement_score(post.platform, post.scheduled_at)
      end
      @engagement_scores[platform[0]] = (total_score / platform_posts.count).round(3) if platform_posts.any?
    end
    
    render 'analytics'
  end

  private
    def set_scheduled_post
      @scheduled_post = current_user.scheduled_posts.find(params[:id])
    end

    def scheduled_post_params
      params.require(:scheduled_post).permit(:content_id, :social_account_id, :scheduled_at, :status, :posted_at)
    end

    def trigger_automation(event_type, post)
      return unless current_user
      service = AutomationRulesService.new(current_user)
      service.execute_rules(event_type, { post: post, user: current_user })
    rescue => e
      Rails.logger.error "[Automation] Error: #{e.message}"
    end
end