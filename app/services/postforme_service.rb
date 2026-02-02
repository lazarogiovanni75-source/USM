# frozen_string_literal: true

# Service for posting content via Postforme API
# Replaces Buffer integration for direct social media posting/scheduling
#
# Postforme API Documentation: https://postforme.com/api/docs
class PostformeService
  BASE_URL = 'https://postforme.com/api/v1'
  TIMEOUT = 30

  def initialize(api_key = nil)
    @api_key = api_key || fetch_api_key
  end

  # Post content to a social media profile
  # @param profile_id [String] Social profile ID
  # @param text [String] Content text to post
  # @param options [Hash] Additional options (media, scheduled_at, etc.)
  # @return [Hash] API response
  def create_post(profile_id, text, options = {})
    payload = build_payload(profile_id, text, options)
    post_request('/posts', payload)
  end

  # Schedule a post for later
  # @param profile_id [String] Social profile ID
  # @param text [String] Content text
  # @param scheduled_at [Time] When to post
  # @param options [Hash] Additional options
  # @return [Hash] API response
  def schedule_post(profile_id, text, scheduled_at, options = {})
    payload = build_payload(profile_id, text, options.merge(scheduled_at: scheduled_at))
    post_request('/posts/schedule', payload)
  end

  # Get list of profiles for the authenticated account
  # @return [Array] List of profiles
  def profiles
    get_request('/profiles')
  end

  # Get specific profile details
  # @param profile_id [String] Profile ID
  # @return [Hash] Profile details
  def profile(profile_id)
    get_request("/profiles/#{profile_id}")
  end

  # Get pending posts for a profile
  # @param profile_id [String] Profile ID
  # @return [Array] List of pending posts
  def pending_posts(profile_id)
    get_request("/profiles/#{profile_id}/posts/pending")
  end

  # Get sent/published posts for a profile
  # @param profile_id [String] Profile ID
  # @return [Array] List of sent posts
  def sent_posts(profile_id)
    get_request("/profiles/#{profile_id}/posts/sent")
  end

  # Delete a scheduled post
  # @param post_id [String] Post ID to delete
  # @return [Hash] API response
  def delete_post(post_id)
    delete_request("/posts/#{post_id}")
  end

  # Share a scheduled post immediately
  # @param post_id [String] Post ID
  # @return [Hash] API response
  def share_now(post_id)
    post_request("/posts/#{post_id}/share", {})
  end

  # Get post details by ID
  # @param post_id [String] Post ID
  # @return [Hash] Post details
  def post(post_id)
    get_request("/posts/#{post_id}")
  end

  # Get analytics for a specific post
  # @param post_id [String] Post ID
  # @return [Hash] Analytics data (clicks, impressions, engagement)
  def post_analytics(post_id)
    get_request("/posts/#{post_id}/analytics")
  end

  # Get analytics for a profile (aggregated)
  # @param profile_id [String] Profile ID
  # @param start_date [String] ISO8601 date
  # @param end_date [String] ISO8601 date
  # @return [Hash] Aggregated analytics
  def profile_analytics(profile_id, start_date = nil, end_date = nil)
    endpoint = "/profiles/#{profile_id}/analytics"
    params = []
    params << "start_date=#{start_date}" if start_date.present?
    params << "end_date=#{end_date}" if end_date.present?

    if params.any?
      get_request("#{endpoint}?#{params.join('&')}")
    else
      get_request(endpoint)
    end
  end

  # Check if service is configured
  def configured?
    @api_key.present?
  end

  private

  attr_reader :api_key

  def fetch_api_key
    ENV.fetch('POSTFORME_API_KEY') do
      Rails.application.config.x.postforme_api_key ||
        Rails.application.config_for(:application)['POSTFORME_API_KEY']
    end
  rescue KeyError
    Rails.logger.warn('[PostformeService] API key not configured. Set POSTFORME_API_KEY in environment.')
    nil
  end

  def build_payload(profile_id, text, options)
    payload = {
      api_key: api_key,
      profile_id: profile_id,
      content: text
    }

    if options[:media].present?
      payload[:media] = options[:media]
    end

    if options[:scheduled_at].present?
      payload[:scheduled_at] = format_scheduled_at(options[:scheduled_at])
    end

    payload[:now] = true if options[:now] == true
    payload[:share_now] = true if options[:share_now] == true

    payload
  end

  def format_scheduled_at(time)
    case time
    when String
      time
    when Time, DateTime, ActiveSupport::TimeWithZone
      time.iso8601
    else
      nil
    end
  end

  def post_request(endpoint, payload)
    url = "#{BASE_URL}#{endpoint}"
    Rails.logger.info("[PostformeService] POST #{url}")

    begin
      response = HTTParty.post(url, body: payload, timeout: TIMEOUT)
      log_response(response)
      handle_response(response)
    rescue HTTParty::Error => e
      log_error(e)
      raise PostformeError, "HTTParty error: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => e
      log_error(e)
      raise PostformeError, "Connection timeout: #{e.message}"
    rescue SocketError, Errno::ECONNREFUSED => e
      log_error(e)
      raise PostformeError, "Connection refused: #{e.message}"
    rescue StandardError => e
      log_error(e)
      raise PostformeError, "Unknown error: #{e.message}"
    end
  end

  def get_request(endpoint)
    url = "#{BASE_URL}#{endpoint}?api_key=#{api_key}"
    Rails.logger.info("[PostformeService] GET #{url}")

    begin
      response = HTTParty.get(url, timeout: TIMEOUT)
      log_response(response)
      handle_response(response)
    rescue HTTParty::Error => e
      log_error(e)
      raise PostformeError, "HTTParty error: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => e
      log_error(e)
      raise PostformeError, "Connection timeout: #{e.message}"
    rescue SocketError, Errno::ECONNREFUSED => e
      log_error(e)
      raise PostformeError, "Connection refused: #{e.message}"
    rescue StandardError => e
      log_error(e)
      raise PostformeError, "Unknown error: #{e.message}"
    end
  end

  def delete_request(endpoint)
    url = "#{BASE_URL}#{endpoint}?api_key=#{api_key}"
    Rails.logger.info("[PostformeService] DELETE #{url}")

    begin
      response = HTTParty.delete(url, timeout: TIMEOUT)
      log_response(response)
      handle_response(response)
    rescue HTTParty::Error => e
      log_error(e)
      raise PostformeError, "HTTParty error: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => e
      log_error(e)
      raise PostformeError, "Connection timeout: #{e.message}"
    rescue SocketError, Errno::ECONNREFUSED => e
      log_error(e)
      raise PostformeError, "Connection refused: #{e.message}"
    rescue StandardError => e
      log_error(e)
      raise PostformeError, "Unknown error: #{e.message}"
    end
  end

  def handle_response(response)
    case response.code
    when 200..299
      response.parsed_response
    when 401
      raise PostformeError, 'Invalid API key'
    when 403
      raise PostformeError, 'Access denied'
    when 404
      raise PostformeError, 'Resource not found'
    when 422
      error_msg = response.parsed_response['error'] || response.parsed_response['message'] || 'Validation error'
      raise PostformeError, "Validation failed: #{error_msg}"
    when 429
      raise PostformeError, 'Rate limit exceeded'
    when 500..599
      raise PostformeError, "Server error: #{response.code}"
    else
      raise PostformeError, "Unexpected response: #{response.code}"
    end
  end

  def log_response(response)
    Rails.logger.debug("[PostformeService] Response: #{response.code}")
  end

  def log_error(exception)
    Rails.logger.error("[PostformeService] Error: #{exception.class} - #{exception.message}")
  end

  class PostformeError < StandardError; end
end
