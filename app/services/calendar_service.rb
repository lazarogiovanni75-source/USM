class CalendarService
  def self.suggest_optimal_times(user, date)
    # Analyze user's historical posting data to suggest optimal times
    suggestions = []
    
    # Platform-specific optimal times
    platform_times = {
      instagram: [9, 11, 14, 17], # 9am, 11am, 2pm, 5pm
      twitter: [8, 12, 18, 21],    # 8am, 12pm, 6pm, 9pm  
      linkedin: [8, 9, 12, 17],   # 8am, 9am, 12pm, 5pm
      facebook: [13, 15, 19, 21], # 1pm, 3pm, 7pm, 9pm
      tiktok: [6, 10, 19, 20]    # 6am, 10am, 7pm, 8pm
    }
    
    # Generate suggestions for each platform
    platform_times.each do |platform, hours|
      hours.each do |hour|
        scheduled_time = date.beginning_of_day + hour.hours
        suggestions << {
          platform: platform.to_s,
          time: scheduled_time,
          confidence: calculate_confidence(user, platform, hour),
          reason: get_time_reason(hour, platform)
        }
      end
    end
    
    suggestions.sort_by { |s| -s[:confidence] }.take(10)
  end
  
  def self.calculate_confidence(user, platform, hour)
    # Calculate confidence based on user's posting history and general best practices
    base_score = 0.5
    
    # Check if user has posted at similar times before
    past_posts = user.scheduled_posts.where("EXTRACT(hour FROM scheduled_at) = ?", hour).where.not(status: 'failed')
    if past_posts.any?
      base_score += 0.3
    end
    
    # Platform-specific adjustments
    platform_adjustments = {
      instagram: { peak_hours: [9, 11, 14, 17], boost: 0.2 },
      twitter: { peak_hours: [8, 12, 18, 21], boost: 0.15 },
      linkedin: { peak_hours: [8, 9, 12, 17], boost: 0.25 },
      facebook: { peak_hours: [13, 15, 19, 21], boost: 0.2 },
      tiktok: { peak_hours: [6, 10, 19, 20], boost: 0.3 }
    }
    
    platform_config = platform_adjustments[platform.to_sym]
    if platform_config && platform_config[:peak_hours].include?(hour)
      base_score += platform_config[:boost]
    end
    
    [base_score, 1.0].min
  end
  
  def self.get_time_reason(hour, platform)
    platform_reasons = {
      instagram: {
        9 => "Morning engagement peak",
        11 => "Lunch break browsing",
        14 => "Afternoon break time",
        17 => "After work scrolling"
      },
      twitter: {
        8 => "Morning commute time",
        12 => "Lunch break tweets",
        18 => "Evening engagement",
        21 => "Prime time for discussions"
      },
      linkedin: {
        8 => "Start of workday",
        9 => "Peak professional hours",
        12 => "Lunch break professional content",
        17 => "End of workday reflection"
      },
      facebook: {
        13 => "Afternoon leisure time",
        15 => "Mid-afternoon break",
        19 => "Evening family time",
        21 => "Prime social time"
      },
      tiktok: {
        6 => "Early morning scroll",
        10 => "Late morning entertainment",
        19 => "Evening prime time",
        20 => "Peak engagement hours"
      }
    }
    
    platform_reasons.dig(platform.to_sym, hour) || "Optimal posting time"
  end
  
  def self.analyze_content_gaps(user, date_range)
    # Analyze gaps in content calendar and suggest content
    gaps = []
    
    start_date = date_range.begin
    end_date = date_range.end
    
    # Get all scheduled posts for the period
    scheduled_posts = user.scheduled_posts.where('scheduled_at >= ? AND scheduled_at <= ?', start_date, end_date)
    
    # Find days with no posts
    current_date = start_date
    while current_date <= end_date
      day_posts = scheduled_posts.where('DATE(scheduled_at) = ?', current_date)
      gaps << {
        date: current_date,
        gap_type: 'no_posts',
        suggested_action: 'schedule_content',
        reason: 'No content scheduled for this day'
      } if day_posts.empty?
      
      current_date += 1.day
    end
    
    # Analyze posting frequency by platform
    platform_distribution = scheduled_posts.group(:platform).count
    platforms = ['instagram', 'twitter', 'facebook', 'linkedin', 'tiktok']
    
    platforms.each do |platform|
      platform_posts = scheduled_posts.where(platform: platform)
      gap_threshold = scheduled_posts.count / platforms.length * 0.5 # Less than 50% of average
      
      if platform_posts.count < gap_threshold
        gaps << {
          date: start_date,
          gap_type: 'platform_gap',
          platform: platform,
          suggested_action: 'schedule_platform_content',
          reason: "Low #{platform} posting frequency"
        }
      end
    end
    
    gaps
  end
  
  def self.generate_weekly_content_ideas(user, week_start_date)
    # Generate content ideas based on trends and user's preferences
    ideas = []
    
    # Seasonal suggestions based on date
    month = week_start_date.month
    day_of_week = week_start_date.wday
    
    seasonal_ideas = {
      1 => { mood: "New Year fresh start", topics: ["goals", "fresh start", "motivation"] },
      2 => { mood: "Valentine's month", topics: ["love", "relationships", "appreciation"] },
      3 => { mood: "Spring preparation", topics: ["spring", "renewal", "growth"] },
      4 => { mood: "Spring cleaning", topics: ["organization", "cleaning", "refresh"] },
      5 => { mood: "Mother's Day season", topics: ["mothers", "family", "gratitude"] },
      6 => { mood: "Summer vibes", topics: ["summer", "outdoors", "energy"] },
      7 => { mood: "Mid-summer fun", topics: ["vacation", "travel", "relaxation"] },
      8 => { mood: "Summer end", topics: ["back to school", "routine", "planning"] },
      9 => { mood: "Fall preparation", topics: ["autumn", "change", "preparation"] },
      10 => { mood: "Halloween season", topics: ["halloween", "autumn", "festive"] },
      11 => { mood: "Thanksgiving month", topics: ["gratitude", "thanksgiving", "family"] },
      12 => { mood: "Holiday season", topics: ["holidays", "festive", "year-end"] }
    }
    
    seasonal = seasonal_ideas[month]
    
    # Generate daily ideas for the week
    7.times do |i|
      date = week_start_date + i.days
      topics = seasonal ? seasonal[:topics] : ["general", "inspiration", "tips"]
      random_topic = topics.sample
      
      ideas << {
        date: date,
        topic: random_topic,
        content_type: ['post', 'story', 'reel', 'article'].sample,
        platform: ['instagram', 'twitter', 'linkedin', 'facebook'].sample,
        prompt: "Create #{random_topic} content for #{date.strftime('%A')}",
        seasonal_context: seasonal ? seasonal[:mood] : nil
      }
    end
    
    ideas
  end
  
  def self.get_engagement_predictions(user, date_range)
    # Predict engagement levels for scheduled posts
    predictions = []
    
    posts = user.scheduled_posts.where('scheduled_at >= ? AND scheduled_at <= ?', date_range.begin, date_range.end)
    
    posts.each do |post|
      prediction = {
        post_id: post.id,
        predicted_engagement: predict_single_post_engagement(post),
        confidence: calculate_prediction_confidence(post),
        factors: get_engagement_factors(post)
      }
      predictions << prediction
    end
    
    predictions
  end
  
  def self.predict_single_post_engagement(post)
    base_score = 0.5
    
    # Time of day factor
    hour = post.scheduled_at.hour
    if (9..11).include?(hour) || (14..17).include?(hour)
      base_score += 0.2 # Peak hours
    end
    
    # Day of week factor
    day = post.scheduled_at.wday
    if [1, 2, 3, 4, 5].include?(day) # Weekdays
      base_score += 0.1
    elsif [6, 0].include?(day) # Weekends
      base_score += 0.15
    end
    
    # Platform factor
    platform_engagement_rates = {
      instagram: 0.15,
      twitter: 0.05,
      facebook: 0.08,
      linkedin: 0.12,
      tiktok: 0.25
    }
    
    base_score += platform_engagement_rates[post.platform.to_sym] || 0.1
    
    [base_score, 1.0].min.round(3)
  end
  
  def self.calculate_prediction_confidence(post)
    # Higher confidence for posts with complete metadata
    confidence = 0.5
    
    confidence += 0.2 if post.content.present?
    confidence += 0.15 if post.platform.present?
    confidence += 0.1 if post.scheduled_at.present?
    
    [confidence, 1.0].min.round(3)
  end
  
  def self.get_engagement_factors(post)
    factors = []
    
    # Time factors
    hour = post.scheduled_at.hour
    if (9..11).include?(hour)
      factors << { type: 'time', factor: 'peak_morning_hours', impact: 'positive' }
    elsif (14..17).include?(hour)
      factors << { type: 'time', factor: 'afternoon_engagement', impact: 'positive' }
    end
    
    # Platform factors
    platform_factors = {
      instagram: 'high_visual_engagement',
      twitter: 'quick_consumption',
      linkedin: 'professional_focus',
      facebook: 'social_sharing',
      tiktok: 'viral_potential'
    }
    
    if platform_factors[post.platform.to_sym]
      factors << { type: 'platform', factor: platform_factors[post.platform.to_sym], impact: 'positive' }
    end
    
    factors
  end
end