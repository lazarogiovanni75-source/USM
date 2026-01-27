class SchedulerService < ApplicationService
  def initialize(user = nil)
    @user = user
  end

  def call
    # Default action - return service info
    { service: 'SchedulerService', status: 'ready', methods: [:calculate_optimal_time, :calculate_optimal_times, :analyze_scheduling_impact] }
  end

  def calculate_optimal_time(platform, target_audience = nil)
    # Platform-specific optimal posting times (based on research)
    optimal_times = {
      instagram: [9, 11, 14, 17], # 9am, 11am, 2pm, 5pm
      twitter: [8, 12, 18, 21],    # 8am, 12pm, 6pm, 9pm  
      linkedin: [8, 9, 12, 17],   # 8am, 9am, 12pm, 5pm
      facebook: [13, 15, 19, 21], # 1pm, 3pm, 7pm, 9pm
      tiktok: [6, 10, 19, 20]    # 6am, 10am, 7pm, 8pm
    }
    
    platform_times = optimal_times[platform.to_sym] || optimal_times[:instagram]
    
    # Find next optimal time
    now = Time.current
    today = now.to_date
    
    platform_times.each do |hour|
      candidate_time = today.to_datetime.change(hour: hour, minute: 0, second: 0)
      if candidate_time > now
        return candidate_time
      end
    end
    
    # If no time today, schedule for tomorrow at first optimal time
    tomorrow = today + 1.day
    tomorrow.to_datetime.change(hour: platform_times.first, minute: 0, second: 0)
  end

  def calculate_optimal_times(platform, target_audience = nil)
    optimal_times = {
      instagram: {
        times: [[9, "Morning engagement peak"], [11, "Lunch break browsing"], 
                [14, "Afternoon break time"], [17, "After work scrolling"]],
        confidence: 0.85
      },
      twitter: {
        times: [[8, "Morning commute"], [12, "Lunch break tweets"], 
                [18, "Evening engagement"], [21, "Prime discussions"]],
        confidence: 0.75
      },
      linkedin: {
        times: [[8, "Start of workday"], [9, "Peak professional hours"], 
                [12, "Lunch professional content"], [17, "End of workday"]],
        confidence: 0.90
      },
      facebook: {
        times: [[13, "Afternoon leisure"], [15, "Mid-afternoon break"], 
                [19, "Evening family time"], [21, "Prime social time"]],
        confidence: 0.70
      },
      tiktok: {
        times: [[6, "Early morning scroll"], [10, "Late morning entertainment"], 
                [19, "Evening prime time"], [20, "Peak engagement"]],
        confidence: 0.95
      }
    }
    
    platform_data = optimal_times[platform.to_sym] || optimal_times[:instagram]
    platform_data[:times].map do |hour, reason|
      {
        hour: hour,
        reason: reason,
        platform: platform
      }
    end
  end

  def analyze_scheduling_impact(post_ids, new_time)
    # Analyze potential conflicts and optimal spacing
    posts = @user.scheduled_posts.where(id: post_ids) if @user
    
    analysis = {
      conflicts: [],
      recommendations: [],
      optimal_spacing: true
    }
    
    # Check for conflicts (posts too close together)
    if posts.present?
      posts.each do |post|
        # Check for posts within 30 minutes
        nearby_posts = @user.scheduled_posts
          .where.not(id: post.id)
          .where('ABS(EXTRACT(EPOCH FROM scheduled_at - ?) / 60) < ?', new_time, 30)
          .exists?
        
        if nearby_posts
          analysis[:conflicts] << "Post scheduled too close to another scheduled post"
        end
      end
    end
    
    # Generate recommendations
    if analysis[:conflicts].empty?
      analysis[:recommendations] << "Good scheduling - posts are well spaced"
    else
      analysis[:recommendations] << "Consider rescheduling to avoid conflicts"
    end
    
    analysis
  end

  def suggest_schedule_batch(posts_data, platform)
    # Suggest optimal schedule for a batch of posts
    suggested_schedule = []
    base_time = Time.current.beginning_of_hour
    
    optimal_times = calculate_optimal_times(platform)
    time_index = 0
    
    posts_data.each_with_index do |post_data, index|
      # Space posts at least 2 hours apart
      suggested_time = base_time + (index * 2).hours
      
      # Use optimal times if available
      if optimal_times[time_index % optimal_times.length]
        suggested_time = suggested_time.change(
          hour: optimal_times[time_index % optimal_times.length][:hour]
        )
      end
      
      suggested_schedule << {
        post_data: post_data,
        suggested_time: suggested_time,
        confidence: optimal_times.dig(time_index % optimal_times.length, :confidence) || 0.5
      }
      
      time_index += 1
    end
    
    suggested_schedule
  end

  def calculate_platform_engagement_score(platform, time)
    # Calculate engagement score based on historical data and platform analytics
    base_scores = {
      instagram: 0.75,
      twitter: 0.60,
      linkedin: 0.85,
      facebook: 0.70,
      tiktok: 0.90
    }
    
    base_score = base_scores[platform.to_sym] || 0.70
    
    # Time-based adjustments
    hour = time.hour
    day_of_week = time.wday
    
    # Peak hours boost
    peak_hours = {
      instagram: [9, 11, 14, 17],
      twitter: [8, 12, 18, 21],
      linkedin: [8, 9, 12, 17],
      facebook: [13, 15, 19, 21],
      tiktok: [6, 10, 19, 20]
    }
    
    if peak_hours[platform.to_sym]&.include?(hour)
      base_score += 0.15
    end
    
    # Weekend adjustments
    if [0, 6].include?(day_of_week) # Sunday or Saturday
      case platform.to_sym
      when :facebook, :instagram, :tiktok
        base_score += 0.10
      when :linkedin
        base_score -= 0.20
      end
    end
    
    [base_score, 1.0].min
  end

  def batch_schedule_optimization(post_ids)
    # Optimize scheduling for a batch of posts
    posts = @user.scheduled_posts.where(id: post_ids)
    optimization_results = []
    
    posts.each do |post|
      current_score = calculate_platform_engagement_score(post.platform, post.scheduled_at)
      
      # Try alternative times within next 7 days
      alternative_scores = []
      7.times do |day_offset|
        (6..22).each do |hour| # 6am to 10pm
          candidate_time = (Time.current + day_offset.days).change(hour: hour, minute: 0)
          score = calculate_platform_engagement_score(post.platform, candidate_time)
          
          alternative_scores << {
            time: candidate_time,
            score: score,
            improvement: score - current_score
          }
        end
      end
      
      # Find best alternative
      best_alternative = alternative_scores.max_by { |alt| alt[:improvement] }
      
      if best_alternative[:improvement] > 0.05 # 5% improvement threshold
        optimization_results << {
          post_id: post.id,
          current_time: post.scheduled_at,
          suggested_time: best_alternative[:time],
          current_score: current_score,
          suggested_score: best_alternative[:score],
          improvement: best_alternative[:improvement]
        }
      end
    end
    
    optimization_results
  end

  def reschedule_with_conflicts_resolution(post_id, new_time)
    post = @user.scheduled_posts.find(post_id) if @user
    return { success: false, error: "Post not found" } unless post
    
    # Check for conflicts
    conflicts = @user.scheduled_posts
      .where.not(id: post.id)
      .where('ABS(EXTRACT(EPOCH FROM scheduled_at - ?) / 60) < ?', new_time, 30)
      .order(:scheduled_at)
    
    if conflicts.any?
      # Try to find next available slot
      suggested_time = find_next_available_slot(new_time, conflicts.first.scheduled_at)
      
      {
        success: false,
        error: "Time conflict detected",
        conflicts: conflicts.pluck(:id),
        suggested_time: suggested_time
      }
    else
      # Update the post
      if post.update(scheduled_at: new_time)
        {
          success: true,
          message: "Post rescheduled successfully",
          post: post
        }
      else
        {
          success: false,
          error: "Failed to update post",
          errors: post.errors.full_messages
        }
      end
    end
  end

  private

  def find_next_available_slot(requested_time, conflict_time)
    # Find next 30-minute slot after the conflict
    conflict_end_time = conflict_time + 30.minutes
    
    # If requested time is after conflict, use it
    if requested_time > conflict_end_time
      requested_time
    else
      # Find next available slot
      current_time = conflict_end_time
      
      48.times do # Check next 24 hours in 30-minute increments
        # Check if this slot is available
        is_available = !@user.scheduled_posts
          .where('ABS(EXTRACT(EPOCH FROM scheduled_at - ?) / 60) < 30', current_time)
          .exists?
        
        return current_time if is_available
        current_time += 30.minutes
      end
      
      # If no slot found, return original requested time
      requested_time
    end
  end
end
