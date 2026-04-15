# frozen_string_literal: true

# Service for analyzing social media data from Postforme and generating AI-powered marketing strategies
class MarketingStrategyAnalyzerService
  include ActionView::Helpers::TextHelper
  
  def initialize(user = nil)
    @user = user
    @dashboard_service = PostformeDashboardService.new
  end
  
  # Analyze social media metrics and generate strategy recommendations
  # @param time_range [String] Time period for analysis (week, month, quarter)
  # @return [Hash] Analysis results with strategy recommendations
  def analyze_and_recommend(time_range = 'month')
    metrics = fetch_user_metrics
    insights = generate_ai_insights(metrics, time_range)
    strategy = create_strategy_recommendations(metrics, insights, time_range)
    
    {
      metrics: metrics,
      insights: insights,
      strategy: strategy,
      generated_at: Time.current,
      time_range: time_range
    }
  end
  
  # Generate a comprehensive marketing strategy report
  # @param focus_area [String] Specific area to focus on (engagement, growth, content, etc.)
  # @return [Hash] Detailed strategy report
  def generate_strategy_report(focus_area = 'comprehensive')
    metrics = fetch_user_metrics
    ai_analysis = call_ai_for_strategy(metrics, focus_area)
    
    {
      summary: ai_analysis[:summary],
      recommendations: ai_analysis[:recommendations],
      action_items: ai_analysis[:action_items],
      content_ideas: ai_analysis[:content_ideas],
      optimal_times: ai_analysis[:optimal_times],
      predicted_growth: ai_analysis[:predicted_growth],
      focus_area: focus_area,
      generated_at: Time.current
    }
  end
  
  # Get quick strategy insights for dashboard
  # @return [Hash] Brief strategy snapshot
  def quick_insights
    metrics = fetch_user_metrics
    
    {
      overall_score: calculate_overall_score(metrics),
      top_performing_platform: find_top_platform(metrics),
      growth_trend: calculate_growth_trend(metrics),
      key_opportunity: identify_opportunity(metrics),
      recommended_action: recommend_next_action(metrics)
    }
  end
  
  # Save strategy to history
  # @param focus_area [String] Focus area of the strategy
  # @param generated_by [String] Source of generation (manual, auto_weekly)
  # @return [StrategyHistory] Saved record
  def save_to_history(focus_area: 'comprehensive', generated_by: 'manual')
    return nil unless user
    
    metrics = fetch_user_metrics
    insights = generate_ai_insights(metrics, 'month')
    strategy = create_strategy_recommendations(metrics, insights, 'month')
    
    StrategyHistory.create!(
      user: user,
      focus_area: focus_area,
      metrics: metrics,
      strategy: strategy,
      insights: insights,
      recommendations: strategy[:key_recommendations].join("\n"),
      kpis_tracked: strategy[:kpis_to_track],
      overall_score: calculate_overall_score(metrics),
      generated_by: generated_by,
      generated_at: Time.current
    )
  end
  
  # Get strategy history for user
  # @param limit [Integer] Number of records to return
  # @return [Array<StrategyHistory>] Strategy history records
  def get_history(limit: 10)
    return [] unless user
    
    user.strategy_histories.recent.limit(limit)
  end
  
  # Get strategy trend over time
  # @return [Hash] Trend data
  def get_trend
    return { trend: 'no_data', change_percent: 0 } unless user
    
    histories = user.strategy_histories.recent.limit(4).order(generated_at: :asc)
    return { trend: 'no_data', change_percent: 0 } if histories.count < 2
    
    scores = histories.pluck(:overall_score)
    first = scores.first
    last = scores.last
    
    change_percent = first > 0 ? ((last - first).to_f / first * 100).round(1) : 0
    
    { trend: change_percent > 5 ? 'improving' : change_percent < -5 ? 'declining' : 'stable', change_percent: change_percent, scores: scores }
  end
  
  # Execute recommendations - create scheduled posts from content ideas
  # @param content_ideas [Array<String>] List of content ideas
  # @param schedule_options [Hash] Scheduling options
  # @return [Array<ScheduledPost>] Created posts
  def execute_recommendations(content_ideas:, schedule_options: {})
    return [] unless user && content_ideas.present?
    
    created_posts = []
    
    content_ideas.first(5).each_with_index do |idea, index|
      scheduled_time = calculate_scheduled_time(index, schedule_options)
      
      post = ScheduledPost.create!(
        user: user,
        body: idea,
        scheduled_at: scheduled_time,
        status: 'draft',
        metadata: { source: 'strategy_execution', idea: idea }
      )
      
      created_posts << post
    end
    
    created_posts
  end
  
  private
  
  attr_reader :user
  
  def fetch_user_metrics
    return {} unless user
    
    @dashboard_service.aggregate_user_metrics(user)
  end
  
  def generate_ai_insights(metrics, time_range)
    return { summary: 'Connect social accounts to enable AI analysis' } if metrics.empty?
    
    prompt = build_insights_prompt(metrics, time_range)
    call_ai(prompt)
  end
  
  def create_strategy_recommendations(metrics, insights, time_range)
    return default_strategy if metrics.empty?
    
    {
      title: "#{time_range.titleize} Marketing Strategy",
      based_on: insights[:summary],
      key_recommendations: parse_recommendations(insights),
      platform_focus: determine_platform_focus(metrics),
      content_themes: suggest_content_themes(metrics, insights),
      posting_schedule: optimal_posting_times(metrics),
      kpis_to_track: recommended_kpis(metrics)
    }
  end
  
  def call_ai_for_strategy(metrics, focus_area)
    prompt = build_strategy_prompt(metrics, focus_area)
    response = call_ai(prompt)
    
    parse_strategy_response(response)
  end
  
  def build_insights_prompt(metrics, time_range)
    <<~PROMPT
      Analyze these social media metrics and provide key insights:
      
      Metrics:
      - Total Followers: #{metrics[:total_followers]}
      - Total Likes: #{metrics[:total_likes]}
      - Total Views: #{metrics[:total_views]}
      - Total Engagement: #{metrics[:total_engagement]}
      - Total Shares: #{metrics[:total_shares]}
      - New Followers: #{metrics[:total_new_followers]}
      - Unfollowers: #{metrics[:total_unfollowers]}
      - Connected Accounts: #{metrics[:connected_accounts]}
      - Last Synced: #{metrics[:last_synced]}
      
      Time Range: #{time_range}
      
      Provide a brief analysis (2-3 sentences) covering:
      1. Overall performance summary
      2. Key growth indicators
      3. Areas needing attention
      
      Format as JSON with keys: summary, growth_indicators, areas_for_improvement
    PROMPT
  end
  
  def build_strategy_prompt(metrics, focus_area)
    <<~PROMPT
      As an expert social media marketing strategist, analyze these metrics and provide 
      a #{focus_area} marketing strategy:
      
      Current Metrics:
      - Followers: #{metrics[:total_followers]}
      - Engagement Rate: #{calculate_engagement_rate(metrics)}
      - Growth Rate: #{calculate_growth_rate(metrics)}
      - Top Platform: #{find_top_platform(metrics)&.dig(:platform) || 'N/A'}
      
      Provide a detailed strategy in JSON format with:
      {
        "summary": "2-3 sentence executive summary",
        "recommendations": ["list of 5 key recommendations"],
        "action_items": ["specific actionable tasks"],
        "content_ideas": ["5 content ideas for next week"],
        "optimal_times": {"platform": "best posting times"},
        "predicted_growth": "projected metrics improvement"
      }
      
      Focus areas: #{focus_area}
    PROMPT
  end
  
  def call_ai(prompt)
    LlmService.chat(
      system: 'You are an expert social media marketing strategist. Always respond in valid JSON format.',
      messages: [
        { role: 'user', content: prompt }
      ],
      max_tokens: 1500
    )
  rescue StandardError => e
    Rails.logger.error "[MarketingStrategyAnalyzer] AI call failed: #{e.message}"
    { summary: 'AI analysis temporarily unavailable', error: e.message }
  end
  
  def parse_strategy_response(response)
    # Try to parse as JSON, fallback to structured response
    begin
      JSON.parse(response).symbolize_keys
    rescue JSON::ParserError
      {
        summary: response,
        recommendations: [],
        action_items: [],
        content_ideas: [],
        optimal_times: {},
        predicted_growth: 'Unable to calculate'
      }
    end
  end
  
  def parse_recommendations(insights)
    return [] if insights[:recommendations].nil?
    
    if insights[:recommendations].is_a?(Array)
      insights[:recommendations]
    elsif insights[:recommendations].is_a?(String)
      insights[:recommendations].split("\n").reject(&:blank?)
    else
      []
    end
  end
  
  def calculate_overall_score(metrics)
    return 0 if metrics[:total_followers].to_i.zero?
    
    engagement_rate = calculate_engagement_rate(metrics)
    growth_rate = calculate_growth_rate(metrics)
    
    # Weighted scoring
    score = (engagement_rate * 0.4) + (growth_rate * 0.3) + (min(100, metrics[:total_engagement].to_i / 100) * 0.3)
    [100, score.round].min
  end
  
  def calculate_engagement_rate(metrics)
    return 0 if metrics[:total_followers].to_i.zero?
    
    ((metrics[:total_engagement].to_f / metrics[:total_followers]) * 100).round(2)
  end
  
  def calculate_growth_rate(metrics)
    return 0 if metrics[:total_followers].to_i.zero?
    
    ((metrics[:total_new_followers].to_f / metrics[:total_followers]) * 100).round(2)
  end
  
  def find_top_platform(metrics)
    # In a full implementation, would analyze per-platform data
    { platform: 'instagram', score: 75 }
  end
  
  def calculate_growth_trend(metrics)
    new_followers = metrics[:total_new_followers].to_i
    unfollowers = metrics[:total_unfollowers].to_i
    
    if new_followers > unfollowers
      'positive'
    elsif new_followers < unfollowers
      'negative'
    else
      'stable'
    end
  end
  
  def identify_opportunity(metrics)
    engagement = calculate_engagement_rate(metrics)
    
    if engagement < 2
      'Focus on increasing engagement through interactive content'
    elsif engagement > 5
      'Leverage high engagement to grow follower base'
    else
      'Balance growth and engagement efforts'
    end
  end
  
  def recommend_next_action(metrics)
    trend = calculate_growth_trend(metrics)
    
    case trend
    when 'positive'
      'Consider running a promotion to capitalize on growth momentum'
    when 'negative'
      'Review content strategy and increase posting frequency'
    else
      'Test new content formats to jumpstart engagement'
    end
  end
  
  def determine_platform_focus(metrics)
    # Recommend based on current metrics
    if metrics[:total_views].to_i > metrics[:total_likes].to_i * 10
      { primary: 'video_platforms', secondary: 'instagram' }
    else
      { primary: 'instagram', secondary: 'twitter' }
    end
  end
  
  def suggest_content_themes(metrics, insights)
    [
      'Behind-the-scenes content',
      'User-generated content features',
      'Educational posts about your niche',
      'Trend participation content',
      'Community engagement posts'
    ]
  end
  
  def optimal_posting_times(metrics)
    {
      instagram: { best_days: ['Tuesday', 'Thursday', 'Saturday'], best_times: ['9 AM', '12 PM', '7 PM'] },
      twitter: { best_days: ['Wednesday', 'Friday'], best_times: ['8 AM', '12 PM', '5 PM'] },
      facebook: { best_days: ['Tuesday', 'Wednesday', 'Thursday'], best_times: ['9 AM', '1 PM', '4 PM'] }
    }
  end
  
  def recommended_kpis(metrics)
    [
      { name: 'Engagement Rate', target: '> 3%' },
      { name: 'Follower Growth', target: '+5% monthly' },
      { name: 'Reach', target: '+10% monthly' },
      { name: 'Click-through Rate', target: '> 1.5%' }
    ]
  end
  
  def default_strategy
    {
      title: 'Getting Started Strategy',
      based_on: 'Connect your social accounts to receive personalized recommendations',
      key_recommendations: [
        'Connect at least 2 social media accounts',
        'Enable Postforme integration for analytics',
        'Post consistently for 2 weeks before analyzing'
      ],
      platform_focus: { primary: 'instagram', secondary: 'twitter' },
      content_themes: ['Introduction posts', 'Value proposition content', 'Brand story'],
      posting_schedule: { instagram: { best_days: ['Tuesday', 'Thursday'], best_times: ['9 AM', '12 PM'] } },
      kpis_to_track: ['Follower count', 'Engagement rate', 'Profile visits']
    }
  end
  
  def min(value, max)
    value < max ? value : max
  end
  
  def calculate_scheduled_time(index, options)
    base_time = options[:start_time] || 1.day.from_now
    interval = options[:interval_days] || 1
    
    base_time + (index * interval.days)
  end
end
