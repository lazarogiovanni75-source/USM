# frozen_string_literal: true

module Social
  # Client for Postforme API operations
  # Wraps PostformeService with structured responses and controlled exceptions
  class PostformeClient
    BASE_URL = ENV.fetch('POSTFORME_BASE_URL', 'https://api.postforme.dev/v1')
    TIMEOUT = 30

    class Error < StandardError; end
    class ConfigurationError < Error; end
    class NotFoundError < Error; end
    class AuthenticationError < Error; end
    class RateLimitError < Error; end

    def initialize(api_key: nil)
      @api_key = api_key || default_api_key
      raise ConfigurationError, 'API key is required' unless @api_key
    end

    # Publish a post via Postforme
    # @param post [ScheduledPost, Content] Post to publish
    # @return [Hash] Structured result with success, platform_post_id, url
    def publish_post(post)
      social_account = find_social_account(post)
      raise Error, 'No social account configured' unless social_account

      profile_id = social_account.oauth_metadata&.dig('postforme_profile_id')
      raise Error, 'No Postforme profile ID configured' unless profile_id

      caption = build_caption(post)
      media = build_media(post)

      payload = {
        caption: caption,
        social_accounts: [profile_id]
      }
      payload[:media] = media if media.any?

      response = post('/social-posts', payload)

      if response['data'].present?
        platform_post_id = response.dig('data', 'id')
        {
          success: true,
          platform_post_id: platform_post_id,
          post_id: post.id,
          url: response.dig('data', 'url'),
          platform: post.platform,
          data: response['data']
        }
      else
        raise Error, "Failed to publish: #{response.inspect}"
      end
    rescue PostformeClient::NotFoundError => e
      { success: false, error: "Social account not found: #{e.message}" }
    rescue PostformeClient::AuthenticationError => e
      { success: false, error: "Authentication failed: #{e.message}" }
    rescue PostformeClient::RateLimitError => e
      { success: false, error: "Rate limited: #{e.message}" }
    rescue => e
      Rails.logger.error "[PostformeClient] Publish error: #{e.message}"
      { success: false, error: e.message }
    end

    # Fetch metrics for a specific post
    # @param platform_post_id [String] Postforme post ID
    # @return [Hash] Metrics data
    def fetch_metrics(platform_post_id)
      response = get("/social-posts/#{platform_post_id}/analytics")

      if response['data'].present?
        data = response['data']
        {
          success: true,
          platform_post_id: platform_post_id,
          impressions: data.dig('impressions', 'count') || 0,
          likes: data.dig('likes', 'count') || 0,
          comments: data.dig('comments', 'count') || 0,
          shares: data.dig('shares', 'count') || 0,
          saves: data.dig('saves', 'count') || 0,
          clicks: data.dig('clicks', 'count') || 0,
          engagement_rate: calculate_engagement_rate(data),
          raw_metrics: data,
          fetched_at: Time.current.iso8601
        }
      else
        raise Error, "No metrics data returned for post #{platform_post_id}"
      end
    rescue PostformeClient::NotFoundError => e
      { success: false, error: "Post not found: #{e.message}" }
    rescue => e
      Rails.logger.error "[PostformeClient] Fetch metrics error: #{e.message}"
      { success: false, error: e.message }
    end

    private

    attr_reader :api_key

    def default_api_key
      ENV.fetch('POSTFORME_API_KEY', nil)
    end

    def find_social_account(post)
      return nil unless post

      if post.respond_to?(:social_account_id) && post.social_account_id
        SocialAccount.find_by(id: post.social_account_id)
      elsif post.respond_to?(:platform) && post.respond_to?(:user_id)
        SocialAccount.find_by(platform: post.platform, user_id: post.user_id)
      end
    end

    def build_caption(post)
      caption = post.content.to_s.dup

      if post.respond_to?(:hashtags) && post.hashtags.present?
        caption += "\n\n#{post.hashtags}"
      end

      caption
    end

    def build_media(post)
      return [] unless post.respond_to?(:media_url) && post.media_url.present?

      [{ url: post.media_url }]
    end

    def calculate_engagement_rate(data)
      impressions = data.dig('impressions', 'count') || 0
      return 0.0 if impressions.zero?

      total_engagement = [
        data.dig('likes', 'count') || 0,
        data.dig('comments', 'count') || 0,
        data.dig('shares', 'count') || 0,
        data.dig('saves', 'count') || 0
      ].sum

      ((total_engagement.to_f / impressions) * 100).round(2)
    end

    # ==================== HTTP Methods ====================

    def headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{api_key}"
      }
    end

    def request(method, endpoint, body = nil)
      url = "#{BASE_URL}#{endpoint}"
      Rails.logger.info "[PostformeClient] #{method.to_s.upcase} #{url}"

      http = Net::HTTP.new(URI.parse(url).host, URI.parse(url).port || 443)
      http.use_ssl = true
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      req = case method
            when :get then Net::HTTP::Get.new(endpoint)
            when :post then Net::HTTP::Post.new(endpoint)
            when :put then Net::HTTP::Put.new(endpoint)
            when :delete then Net::HTTP::Delete.new(endpoint)
            when :patch then Net::HTTP::Patch.new(endpoint)
            end

      headers.each { |k, v| req[k] = v }
      req.body = body.to_json if body

      begin
        response = http.request(req)
        log_response(response)
        handle_response(response)
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise Error, "Connection timeout: #{e.message}"
      rescue SocketError, Errno::ECONNREFUSED => e
        raise Error, "Connection refused: #{e.message}"
      end
    end

    def get(endpoint)
      request(:get, endpoint)
    end

    def post(endpoint, body)
      request(:post, endpoint, body)
    end

    def put(endpoint, body)
      request(:put, endpoint, body)
    end

    def delete(endpoint)
      request(:delete, endpoint)
    end

    def handle_response(response)
      case response.code
      when 200..299
        JSON.parse(response.body)
      when 401
        raise AuthenticationError, 'Invalid or expired API key'
      when 404
        raise NotFoundError, "Resource not found: #{response.code}"
      when 429
        raise RateLimitError, 'Rate limit exceeded'
      when 500..599
        raise Error, "Server error: #{response.code}"
      else
        raise Error, "Unexpected response: #{response.code} - #{response.body}"
      end
    rescue JSON::ParserError => e
      raise Error, "Invalid JSON response: #{e.message}"
    end

    def log_response(response)
      Rails.logger.debug "[PostformeClient] Response: #{response.code} #{response.message}"
    end
  end
end
