class CalendarController < ApplicationController
  before_action :authenticate_user!
  before_action :set_current_month, only: [:index]

  def index
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
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

  private

  def set_current_month
    @current_month = params[:month] || Date.current.month
    @current_year = params[:year] || Date.current.year
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