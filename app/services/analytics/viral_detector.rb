# Analytics service for detecting viral content across clients
module Analytics
  class ViralDetector
    VIRAL_ENGAGEMENT_RATE = 0.05 # 5% minimum engagement rate
    VIRAL_VELOCITY_THRESHOLD = 0.5 # engagements per hour
    MAX_DAYS_FOR_ANALYSIS = 30
    DEFAULT_TOP_POSTS = 10

    # Detect viral posts from recent content
    # Input: posts or client_id/campaign_id
    # Returns: Array of ViralMetric objects
    def self.detect_viral_posts(posts: nil, client_id: nil, campaign_id: nil, top_n: DEFAULT_TOP_POSTS)
      posts ||= fetch_posts_for_analysis(client_id: client_id, campaign_id: campaign_id)
      
      viral_metrics = []
      
      posts.each do |post|
        metric = ViralMetric.detect_viral(post)
        metric.client_id = client_id if client_id
        metric.campaign_id = campaign_id || post.campaign&.id
        viral_metrics << metric if metric.is_viral
      end

      # Rank and save viral posts
      rank_viral_posts(viral_metrics, top_n)
    end

    # Get trending content for a specific client
    def self.get_trending_for_client(client_id, days: MAX_DAYS_FOR_ANALYSIS, limit: 10)
      posts = ScheduledPost.published
        .where('scheduled_posts.published_at > ?', days.days.ago)
        .joins(:campaign)
        .where(campaigns: { client_id: client_id })
        .includes(:performance_metric, :campaign)

      detect_viral_posts(posts: posts, client_id: client_id, top_n: limit)
    end

    # Get trending content across all agency clients
    def self.get_all_trending(days: MAX_DAYS_FOR_ANALYSIS, limit: 10)
      posts = ScheduledPost.published
        .where('scheduled_posts.published_at > ?', days.days.ago)
        .joins(:campaign)
        .where.not(campaigns: { client_id: nil })
        .includes(:performance_metric, :campaign)

      detect_viral_posts(posts: posts, top_n: limit)
    end

    # Analyze and return viral candidates with context for AI
    def self.get_viral_context_for_ai(client_id: nil, campaign_id: nil)
      posts = if client_id
        get_trending_for_client(client_id, limit: 5)
      else
        get_all_trending(limit: 5)
      end

      return nil if posts.empty?

      context = "Viral Content Analysis:\n\n"
      
      posts.each_with_index do |metric, idx|
        post = metric.scheduled_post
        context += "#{idx + 1}. "
        context += "Engagement Rate: #{(metric.engagement_rate * 100).round(2)}% | "
        context += "Velocity: #{metric.share_velocity.round(2)} eng/hour\n"
        context += "   Content: #{post.content&.truncate(100)}\n"
        context += "   Hashtags: #{metric.top_hashtags.join(', ')}\n\n"
      end

      context
    end

    # Batch store viral metrics (for scheduled job)
    def self.batch_store_metrics(client_id: nil)
      posts = fetch_posts_for_analysis(client_id: client_id)
      
      posts.each do |post|
        # Skip if already analyzed
        next if ViralMetric.where(scheduled_post_id: post.id)
                          .where('detected_at > ?', 1.day.ago)
                          .exists?

        metric = ViralMetric.detect_viral(post)
        metric.client_id = client_id || post.campaign&.client_id
        metric.campaign_id = post.campaign_id
        metric.save if metric.is_viral
      end
    end

    private

    def self.fetch_posts_for_analysis(client_id: nil, campaign_id: nil)
      relation = ScheduledPost.published
        .where('scheduled_posts.published_at > ?', MAX_DAYS_FOR_ANALYSIS.days.ago)
        .joins(:performance_metric)
        .includes(:performance_metric, :campaign)

      relation = relation.where(campaigns: { client_id: client_id }) if client_id
      relation = relation.where(campaign_id: campaign_id) if campaign_id

      relation
    end

    def self.rank_viral_posts(viral_metrics, top_n)
      # Sort by engagement rate and velocity
      ranked = viral_metrics.sort_by { |m| [-m.engagement_rate.to_f, -m.share_velocity.to_f] }
      
      ranked.first(top_n).each_with_index do |metric, idx|
        metric.viral_rank = idx + 1
        metric.save
      end

      ranked.first(top_n)
    end
  end
end
