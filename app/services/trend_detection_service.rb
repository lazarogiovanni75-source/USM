class TrendDetectionService
  def initialize(user = nil)
    @user = user
    @analysis_days = 30
  end

  # Main trend detection method
  def detect_all_trends
    {
      content_trends: detect_content_trends,
      engagement_trends: detect_engagement_trends,
      platform_trends: detect_platform_trends,
      timing_trends: detect_timing_trends,
      sentiment_trends: detect_sentiment_trends,
      topic_trends: detect_topic_trends
    }
  end

  # Detect content type trends
  def detect_content_trends
    contents = @user.contents.published
                  .where('created_at >= ?', @analysis_days.days.ago)
                  .group(:content_type)
                  .count
    
    # Calculate trend direction
    recent_contents = contents
    older_contents = @user.contents.published
                        .where(created_at: (2 * @analysis_days).days.ago..@analysis_days.days.ago)
                        .group(:content_type)
                        .count
    
    trends = []
    content_types = (recent_contents.keys + older_contents.keys).uniq
    
    content_types.each do |content_type|
      recent_count = recent_contents[content_type] || 0
      older_count = older_contents[content_type] || 0
      
      if older_count > 0
        change_percent = ((recent_count - older_count).to_f / older_count * 100).round(1)
        trend = {
          content_type: content_type,
          current_count: recent_count,
          previous_count: older_count,
          change_percent: change_percent,
          trend_direction: change_percent > 10 ? 'rising' : change_percent < -10 ? 'declining' : 'stable'
        }
        trends << trend
      end
    end
    
    trends.sort_by { |t| t[:change_percent].abs }.reverse
  end

  # Detect engagement trends
  def detect_engagement_trends
    metrics = PerformanceMetric.joins(:content)
                             .where(contents: { user_id: @user.id })
                             .where('performance_metrics.created_at >= ?', @analysis_days.days.ago)
                             .group('DATE(created_at)')
                             .sum(:engagement_rate)
    
    if metrics.size < 2
      return []
    end
    
    # Calculate engagement trend
    engagement_trends = []
    metrics_sorted = metrics.sort
    
    (1...metrics_sorted.size).each do |i|
      current_engagement = metrics_sorted[i][1]
      previous_engagement = metrics_sorted[i-1][1]
      
      if previous_engagement > 0
        change_percent = ((current_engagement - previous_engagement).to_f / previous_engagement * 100).round(1)
        engagement_trends << {
          date: metrics_sorted[i][0],
          engagement_rate: current_engagement,
          change_percent: change_percent,
          trend_direction: change_percent > 5 ? 'improving' : change_percent < -5 ? 'declining' : 'stable'
        }
      end
    end
    
    engagement_trends
  end

  # Detect platform performance trends
  def detect_platform_trends
    metrics = PerformanceMetric.joins(:content)
                             .where(contents: { user_id: @user.id })
                             .where('performance_metrics.created_at >= ?', @analysis_days.days.ago)
                             .group(:platform)
                             .sum(:engagement_rate)
    
    platform_trends = []
    platforms = metrics.keys
    
    platforms.each do |platform|
      recent_metrics = PerformanceMetric.joins(:content)
                                      .where(contents: { user_id: @user.id })
                                      .where(performance_metrics: { platform: platform })
                                      .where('performance_metrics.created_at >= ?', @analysis_days.days.ago)
                                      .average(:engagement_rate)
      
      older_metrics = PerformanceMetric.joins(:content)
                                      .where(contents: { user_id: @user.id })
                                      .where(performance_metrics: { platform: platform })
                                      .where(performance_metrics: { created_at: (2 * @analysis_days).days.ago..@analysis_days.days.ago })
                                      .average(:engagement_rate)
      
      if older_metrics
        change_percent = ((recent_metrics - older_metrics).to_f / older_metrics * 100).round(1)
        platform_trends << {
          platform: platform,
          current_engagement: recent_metrics&.round(2) || 0,
          previous_engagement: older_metrics.round(2),
          change_percent: change_percent,
          trend_direction: change_percent > 5 ? 'improving' : change_percent < -5 ? 'declining' : 'stable'
        }
      end
    end
    
    platform_trends.sort_by { |t| t[:change_percent].abs }.reverse
  end

  # Detect optimal posting time trends
  def detect_timing_trends
    posts = @user.contents.published
                .joins(:performance_metrics)
                .where('contents.created_at >= ?', @analysis_days.days.ago)
                .group('EXTRACT(hour FROM contents.created_at)')
                .average(:engagement_rate)
    
    timing_trends = []
    posts.each do |hour, avg_engagement|
      timing_trends << {
        hour: hour.to_i,
        avg_engagement: avg_engagement.round(2),
        performance_score: calculate_performance_score(avg_engagement)
      }
    end
    
    timing_trends.sort_by { |t| t[:avg_engagement] }.reverse
  end

  # Detect sentiment trends in content
  def detect_sentiment_trends
    # Simple sentiment analysis using keyword-based approach
    contents = @user.contents.published
                  .where('created_at >= ?', @analysis_days.days.ago)
                  .order(:created_at)
    
    sentiment_trends = []
    recent_contents = contents.last(10) # Last 10 posts
    older_contents = contents.first(10) # First 10 posts in period
    
    recent_sentiment = calculate_sentiment_score(recent_contents.map(&:body))
    older_sentiment = calculate_sentiment_score(older_contents.map(&:body))
    
    sentiment_trends << {
      period: 'recent',
      sentiment_score: recent_sentiment,
      change_percent: older_sentiment > 0 ? ((recent_sentiment - older_sentiment).to_f / older_sentiment * 100).round(1) : 0,
      trend_direction: recent_sentiment > older_sentiment ? 'improving' : recent_sentiment < older_sentiment ? 'declining' : 'stable'
    }
    
    sentiment_trends
  end

  # Detect topic trends using keyword frequency
  def detect_topic_trends
    contents = @user.contents.published
                  .where('created_at >= ?', @analysis_days.days.ago)
    
    # Extract keywords from titles and body
    recent_keywords = extract_keywords(contents.map(&:title) + contents.map(&:body))
    
    # Compare with previous period
    older_contents = @user.contents.published
                          .where(created_at: (2 * @analysis_days).days.ago..@analysis_days.days.ago)
    
    older_keywords = extract_keywords(older_contents.map(&:title) + older_contents.map(&:body))
    
    topic_trends = []
    all_keywords = (recent_keywords.keys + older_keywords.keys).uniq
    
    all_keywords.each do |keyword|
      recent_freq = recent_keywords[keyword] || 0
      older_freq = older_keywords[keyword] || 0
      
      if older_freq > 0
        change_percent = ((recent_freq - older_freq).to_f / older_freq * 100).round(1)
        topic_trends << {
          keyword: keyword,
          recent_frequency: recent_freq,
          previous_frequency: older_freq,
          change_percent: change_percent,
          trend_direction: change_percent > 20 ? 'rising' : change_percent < -20 ? 'declining' : 'stable'
        }
      end
    end
    
    topic_trends.sort_by { |t| t[:change_percent].abs }.reverse.first(10) # Top 10 trends
  end

  # Generate AI-powered insights
  def generate_insights(trends_data)
    insights = []
    
    # Content type insights
    if trends_data[:content_trends].any?
      top_trend = trends_data[:content_trends].first
      if top_trend[:trend_direction] == 'rising'
        insights << "Your #{top_trend[:content_type]} content is trending up by #{top_trend[:change_percent]}%. Consider creating more #{top_trend[:content_type]} content."
      elsif top_trend[:trend_direction] == 'declining'
        insights << "Your #{top_trend[:content_type]} content is declining by #{top_trend[:change_percent]}%. You might want to review your content strategy."
      end
    end
    
    # Platform insights
    if trends_data[:platform_trends].any?
      best_platform = trends_data[:platform_trends].max_by { |p| p[:avg_engagement] }
      insights << "#{best_platform[:platform].titleize} is performing best with #{best_platform[:avg_engagement]}% engagement. Focus more content there."
    end
    
    # Timing insights
    if trends_data[:timing_trends].any?
      best_hour = trends_data[:timing_trends].max_by { |t| t[:avg_engagement] }
      insights << "Your audience is most engaged at #{best_hour[:hour]}:00. Schedule posts during this time for better results."
    end
    
    insights
  end

  private

  def calculate_performance_score(engagement_rate)
    case engagement_rate
    when 0..2
      'poor'
    when 2..5
      'fair'
    when 5..10
      'good'
    when 10..20
      'excellent'
    else
      'outstanding'
    end
  end

  def calculate_sentiment_score(texts)
    positive_words = %w[great amazing excellent wonderful fantastic good positive love success happy joy perfect brilliant awesome]
    negative_words = %w[bad terrible awful poor negative hate sad angry frustrated difficult problem issue crisis]
    
    total_score = 0
    word_count = 0
    
    texts.each do |text|
      next unless text
      
      words = text.downcase.split(/\W+/)
      words.each do |word|
        next if word.length < 3
        
        if positive_words.include?(word)
          total_score += 1
        elsif negative_words.include?(word)
          total_score -= 1
        end
        word_count += 1
      end
    end
    
    word_count > 0 ? (total_score.to_f / word_count * 100).round(2) : 0
  end

  def extract_keywords(texts)
    keywords = {}
    
    texts.each do |text|
      next unless text
      
      # Remove common stop words and extract meaningful terms
      words = text.downcase.gsub(/[^\w\s]/, '').split(/\s+/)
      
      words.each do |word|
        next if word.length < 3
        next if %w[the and for are with this that have will can your you our about more not from].include?(word)
        
        keywords[word] ||= 0
        keywords[word] += 1
      end
    end
    
    keywords
  end
end