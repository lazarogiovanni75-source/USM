# frozen_string_literal: true

class CompetitorTrackingService
  PLATFORMS = %w[instagram facebook twitter linkedin tiktok youtube pinterest threads snapchat].freeze

  class << self
    def search_competitors(query, platform = nil)
      results = []

      platforms_to_search = platform.present? ? [platform] : PLATFORMS

      platforms_to_search.each do |p|
        begin
          case p
          when 'instagram', 'facebook'
            results.concat(search_meta_competitors(query, p))
          when 'twitter', 'linkedin'
            results.concat(search_linkedin_competitors(query, p))
          when 'youtube'
            results.concat(search_youtube_competitors(query))
          when 'tiktok'
            results.concat(search_tiktok_competitors(query))
          when 'pinterest'
            results.concat(search_pinterest_competitors(query))
          else
            results.concat(search_generic_competitors(query, p))
          end
        rescue StandardError => e
          Rails.logger.warn "[CompetitorTracking] Search failed for #{p}: #{e.message}"
        end
      end

      deduplicate_results(results)
    end

    def track_competitor(competitor)
      return { success: false, error: 'Competitor not found' } unless competitor

      platform = competitor.platform.downcase

      case platform
      when 'instagram', 'facebook'
        fetch_meta_metrics(competitor)
      when 'twitter', 'linkedin'
        fetch_linkedin_metrics(competitor)
      when 'youtube'
        fetch_youtube_metrics(competitor)
      when 'tiktok'
        fetch_tiktok_metrics(competitor)
      else
        fetch_generic_metrics(competitor)
      end
    end

    def refresh_all_metrics
      Competitor.where(is_active: true).find_each do |competitor|
        begin
          track_competitor(competitor)
          # Rate limit to avoid API throttling
          sleep 1
        rescue StandardError => e
          Rails.logger.error "[CompetitorTracking] Failed to refresh #{competitor.handle}: #{e.message}"
        end
      end
    end

    def get_engagement_rate(competitor)
      return 0 unless competitor

      posts = competitor.competitor_posts.where('created_at > ?', 30.days.ago)
      return 0 if posts.empty?

      total_engagement = posts.sum { |p| (p.likes_count || 0) + (p.comments_count || 0) + (p.shares_count || 0) }
      total_followers = competitor.follower_count.to_f

      return 0 if total_followers.zero?

      (total_engagement / total_followers) * 100
    end

    def get_post_frequency(competitor)
      return 0 unless competitor

      posts = competitor.competitor_posts.where('created_at > ?', 30.days.ago)
      return 0 if posts.empty?

      (posts.count / 30.0).round(2)
    end

    def analyze_content_themes(competitor)
      posts = competitor.competitor_posts.order(created_at: :desc).limit(20)

      # Use AI to analyze content themes
      prompt = "Analyze these social media post captions and identify the main content themes/topic categories. Return a list of the top 5 themes with brief descriptions.\n\n"
      prompt += posts.map { |p| "- #{p.caption&.truncate(200)}" }.join("\n")

      result = LlmService.generate_content(prompt: prompt)

      {
        themes: parse_themes_from_ai_response(result[:content] || result[:body] || ''),
        top_hashtags: extract_top_hashtags(posts)
      }
    rescue StandardError => e
      Rails.logger.error "[CompetitorTracking] Theme analysis failed: #{e.message}"
      { themes: [], top_hashtags: [] }
    end

    private

    def search_meta_competitors(query, platform)
      # Simulated search results - in production would use Meta Graph API
      [
        {
          platform: platform,
          handle: query.gsub(' ', '').downcase,
          display_name: query.titleize,
          profile_url: "https://#{platform}.com/#{query.gsub(' ', '').downcase}",
          follower_count: rand(1000..500000),
          is_verified: rand > 0.8
        }
      ]
    rescue StandardError
      []
    end

    def search_linkedin_competitors(query, platform)
      # Simulated search results
      [
        {
          platform: platform,
          handle: query.gsub(' ', '-').downcase,
          display_name: query.titleize,
          profile_url: "https://#{platform}.com/in/#{query.gsub(' ', '-').downcase}",
          follower_count: rand(500..100000),
          is_verified: rand > 0.7
        }
      ]
    rescue StandardError
      []
    end

    def search_youtube_competitors(query)
      # Simulated search results
      [
        {
          platform: 'youtube',
          handle: query.gsub(' ', '').downcase,
          display_name: query.titleize,
          profile_url: "https://youtube.com/@#{query.gsub(' ', '').downcase}",
          follower_count: rand(1000..2000000),
          is_verified: rand > 0.6,
          subscriber_count: rand(1000..2000000)
        }
      ]
    rescue StandardError
      []
    end

    def search_tiktok_competitors(query)
      # Simulated search results
      [
        {
          platform: 'tiktok',
          handle: query.gsub(' ', '').downcase,
          display_name: query.titleize,
          profile_url: "https://tiktok.com/@#{query.gsub(' ', '').downcase}",
          follower_count: rand(10000..5000000),
          is_verified: rand > 0.5
        }
      ]
    rescue StandardError
      []
    end

    def search_pinterest_competitors(query)
      [
        {
          platform: 'pinterest',
          handle: query.gsub(' ', '-').downcase,
          display_name: query.titleize,
          profile_url: "https://pinterest.com/#{query.gsub(' ', '-').downcase}",
          follower_count: rand(500..100000),
          is_verified: rand > 0.6
        }
      ]
    rescue StandardError
      []
    end

    def search_generic_competitors(query, platform)
      [
        {
          platform: platform,
          handle: query.gsub(' ', '').downcase,
          display_name: query.titleize,
          profile_url: "https://#{platform}.com/#{query.gsub(' ', '').downcase}",
          follower_count: rand(100..50000),
          is_verified: false
        }
      ]
    end

    def fetch_meta_metrics(competitor)
      # Simulated metrics fetch
      competitor.update!(
        follower_count: competitor.follower_count.to_i + rand(-100..500),
        following_count: rand(100..10000),
        posts_count: rand(50..5000),
        last_synced_at: Time.current
      )

      # Fetch recent posts
      fetch_recent_posts(competitor, 10)

      { success: true, metrics: competitor.attributes.slice('follower_count', 'following_count', 'posts_count') }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def fetch_linkedin_metrics(competitor)
      competitor.update!(
        follower_count: competitor.follower_count.to_i + rand(-50..200),
        posts_count: rand(20..500),
        last_synced_at: Time.current
      )

      fetch_recent_posts(competitor, 10)

      { success: true }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def fetch_youtube_metrics(competitor)
      # For YouTube, also track subscribers
      competitor.update!(
        follower_count: competitor.follower_count.to_i + rand(-500..1000),
        subscriber_count: competitor.subscriber_count.to_i + rand(-500..1000),
        videos_count: rand(10..500),
        last_synced_at: Time.current
      )

      { success: true }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def fetch_tiktok_metrics(competitor)
      competitor.update!(
        follower_count: competitor.follower_count.to_i + rand(-1000..5000),
        following_count: rand(50..500),
        likes_count: rand(10000..1000000),
        last_synced_at: Time.current
      )

      { success: true }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def fetch_generic_metrics(competitor)
      competitor.update!(
        follower_count: competitor.follower_count.to_i + rand(-100..300),
        last_synced_at: Time.current
      )

      { success: true }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def fetch_recent_posts(competitor, limit = 10)
      # Simulated post fetching - in production would use platform APIs
      # Create or update recent posts with mock data
      (1..limit).each do |i|
        post_data = {
          caption: "Sample post caption #{i} - #{Faker::Lorem.sentence}",
          likes_count: rand(10..10000),
          comments_count: rand(0..500),
          shares_count: rand(0..1000),
          posted_at: i.days.ago
        }

        competitor.competitor_posts.find_or_create_by!(
          platform_post_id: "#{competitor.handle}_#{i}_#{Date.today}"
        ) do |post|
          post.assign_attributes(post_data)
        end
      end
    end

    def deduplicate_results(results)
      seen = Set.new
      results.reject do |r|
        key = "#{r[:platform]}_#{r[:handle]}"
        seen.include?(key) || seen.add(key)
      end
    end

    def parse_themes_from_ai_response(response)
      # Parse AI response to extract themes
      themes = []
      response.scan(/\d+\.\s*[\*\*]?([^\*\n]+)[\*\*]?/i).each do |match|
        themes << match.first.strip if match.first
      end
      themes.first(5)
    rescue StandardError
      []
    end

    def extract_top_hashtags(posts)
      hashtags = []
      posts.each do |post|
        hashtags.concat(post.caption.scan(/#\w+/).map(&:downcase)) if post.caption
      end

      hashtags.group_by(&:itself)
              .transform_values(&:count)
              .sort_by { |_, count| -count }
              .first(10)
              .map { |tag, _| tag }
    end
  end
end