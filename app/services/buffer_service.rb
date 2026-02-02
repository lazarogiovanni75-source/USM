# frozen_string_literal: true

# Service for posting content directly to Buffer API
# Replaces Make webhook integration for direct Buffer posting/scheduling
#
# Buffer API Documentation: https://buffer.com/developers/api
class BufferService
  BASE_URL = 'https://api.bufferapp.com/1'
  TIMEOUT = 30

  def initialize(access_token = nil)
    @access_token = access_token || fetch_access_token
  end

  # Post content to a Buffer profile
  # @param profile_id [String] Buffer profile ID
  # @param text [String] Content text to post
  # @param options [Hash] Additional options (media, scheduled_at, etc.)
  # @return [Hash] API response
  def create_update(profile_id, text, options = {})
    payload = build_payload(profile_id, text, options)
    post_request("/updates/create.json", payload)
  end

  # Get list of profiles for the authenticated user
  # @return [Array] List of profiles
  def profiles
    get_request('/profiles.json')
  end

  # Get specific profile details
  # @param profile_id [String] Buffer profile ID
  # @return [Hash] Profile details
  def profile(profile_id)
    get_request("/profiles/#{profile_id}.json")
  end

  # Get pending updates for a profile
  # @param profile_id [String] Buffer profile ID
  # @return [Array] List of pending updates
  def pending_updates(profile_id)
    get_request("/profiles/#{profile_id}/updates/pending.json")
  end

  # Get sent updates for a profile
  # @param profile_id [String] Buffer profile ID
  # @return [Array] List of sent updates
  def sent_updates(profile_id)
    get_request("/profiles/#{profile_id}/updates/sent.json")
  end

  # Delete an update
  # @param update_id [String] Update ID to delete
  # @return [Hash] API response
  def delete_update(update_id)
    post_request("/updates/#{update_id}/destroy.json", {})
  end

  # Share/update immediately (bypass schedule)
  # @param profile_id [String] Buffer profile ID
  # @param text [String] Content text
  # @param options [Hash] Additional options
  # @return [Hash] API response
  def share_now(profile_id, text, options = {})
    payload = build_payload(profile_id, text, options.merge(top: 'true'))
    post_request("/updates/create.json", payload)
  end

  # Get update details by ID
  # @param update_id [String] Buffer update ID
  # @return [Hash] Update details with analytics
  def update(update_id)
    get_request("/updates/#{update_id}.json")
  end

  # Get analytics for a specific update
  # @param update_id [String] Buffer update ID
  # @return [Hash] Analytics data (clicks, impressions, engagement)
  def update_analytics(update_id)
    get_request("/updates/#{update_id}/analytics.json")
  end

  # Get analytics for a profile (aggregated)
  # @param profile_id [String] Buffer profile ID
  # @param start_date [String] ISO8601 date
  # @param end_date [String] ISO8601 date
  # @return [Hash] Aggregated analytics
  def profile_analytics(profile_id, start_date = nil, end_date = nil)
    endpoint = "/profiles/#{profile_id}/analytics.json"
    params = []
    params << "start_date=#{start_date}" if start_date.present?
    params << "end_date=#{end_date}" if end_date.present?

    if params.any?
      get_request("#{endpoint}?#{params.join('&')}")
    else
      get_request(endpoint)
    end
  end

  # Get update interactions (likes, comments, shares)
  # @param profile_id [String] Buffer profile ID
  # @param update_id [String] Buffer update ID
  # @return [Hash] Interaction data
  def update_interactions(profile_id, update_id)
    get_request("/profiles/#{profile_id}/updates/#{update_id}/interactions.json")
  end

  # Reorder updates in the queue
  # @param profile_id [String] Buffer profile ID
  # @param order [Array] Array of update IDs in new order
  # @return [Hash] API response
  def reorder_updates(profile_id, order)
    payload = {
      access_token: access_token,
      profile_ids: [profile_id],
      order: order
    }
    post_request("/profiles/#{profile_id}/updates/reorder.json", payload)
  end

  # Move update to top of queue
  # @param profile_id [String] Buffer profile ID
  # @param update_id [String] Buffer update ID
  # @return [Hash] API response
  def move_to_top(profile_id, update_id)
    payload = {
      access_token: access_token,
      profile_ids: [profile_id],
      id: update_id
    }
    post_request("/profiles/#{profile_id}/updates/move_to_top.json", payload)
  end

  # Share update immediately
  # @param profile_id [String] Buffer profile ID
  # @param update_id [String] Buffer update ID
  # @return [Hash] API response
  def share_update_now(profile_id, update_id)
    payload = {
      access_token: access_token,
      profile_ids: [profile_id]
    }
    post_request("/updates/#{update_id}/share.json", payload)
  end

  # Check if service is configured
  def configured?
    @access_token.present?
  end

  private

  attr_reader :access_token

  def fetch_access_token
    ENV.fetch('BUFFER_ACCESS_TOKEN') do
      Rails.application.config.x.buffer_access_token ||
        Rails.application.config_for(:application)['BUFFER_ACCESS_TOKEN']
    end
  rescue KeyError
    Rails.logger.warn('[BufferService] Access token not configured. Set BUFFER_ACCESS_TOKEN in environment.')
    nil
  end

  def build_payload(profile_id, text, options)
    {
      access_token: access_token,
      profile_ids: [profile_id],
      text: text,
      media: media_options(options),
      scheduled_at: scheduled_at_option(options),
      now: options[:now] || false,
      top: options[:top] || false,
      retweet: options[:retweet] || {},
      shorten: options.fetch(:shorten, true)
    }.compact
  end

  def media_options(options)
    return nil unless options[:media].present?

    media = {}
    media[:link] = options[:media][:link] if options[:media][:link].present?
    media[:photo] = options[:media][:photo] if options[:media][:photo].present?
    media[:thumbnail] = options[:media][:thumbnail] if options[:media][:thumbnail].present?
    media[:description] = options[:media][:description] if options[:media][:description].present?

    media.present? ? media : nil
  end

  def scheduled_at_option(options)
    return nil unless options[:scheduled_at].present?
    return nil if options[:now] || options[:top]

    # Buffer expects ISO8601 format
    case options[:scheduled_at]
    when String
      options[:scheduled_at]
    when Time, DateTime
      options[:scheduled_at].iso8601
    when ActiveSupport::TimeWithZone
      options[:scheduled_at].iso8601
    else
      nil
    end
  end

  def post_request(endpoint, payload)
    url = "#{BASE_URL}#{endpoint}"
    Rails.logger.info("[BufferService] POST #{url}")

    begin
      response = HTTParty.post(
        url,
        body: payload,
        timeout: TIMEOUT
      )

      log_response(response)
      handle_response(response)
    rescue HTTParty::Error => e
      log_error(e)
      raise BufferError, "HTTParty error: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => e
      log_error(e)
      raise BufferError, "Connection timeout: #{e.message}"
    rescue SocketError, Errno::ECONNREFUSED => e
      log_error(e)
      raise BufferError, "Connection refused: #{e.message}"
    rescue StandardError => e
      log_error(e)
      raise BufferError, "Unknown error: #{e.message}"
    end
  end

  def get_request(endpoint)
    url = "#{BASE_URL}#{endpoint}?access_token=#{access_token}"
    Rails.logger.info("[BufferService] GET #{url}")

    begin
      response = HTTParty.get(
        url,
        timeout: TIMEOUT
      )

      log_response(response)
      handle_response(response)
    rescue HTTParty::Error => e
      log_error(e)
      raise BufferError, "HTTParty error: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => e
      log_error(e)
      raise BufferError, "Connection timeout: #{e.message}"
    rescue SocketError, Errno::ECONNREFUSED => e
      log_error(e)
      raise BufferError, "Connection refused: #{e.message}"
    rescue StandardError => e
      log_error(e)
      raise BufferError, "Unknown error: #{e.message}"
    end
  end

  def handle_response(response)
    case response.code
    when 200
      response.parsed_response
    when 401
      raise BufferError, 'Unauthorized - Check your Buffer access token'
    when 403
      raise BufferError, 'Forbidden - Check your Buffer permissions'
    when 404
      raise BufferError, 'Not found - Check the profile ID or update ID'
    when 429
      raise BufferError, 'Rate limited - Too many requests'
    when 500..599
      raise BufferError, "Buffer server error: #{response.code}"
    else
      raise BufferError, "Unexpected response: #{response.code}"
    end
  end

  def log_response(response)
    if response.success?
      Rails.logger.debug("[BufferService] Response: #{response.code}")
    else
      Rails.logger.warn("[BufferService] Response: #{response.code} - #{response.body&.slice(0, 200)}")
    end
  end

  def log_error(exception)
    Rails.logger.error("[BufferService] Error: #{exception.class} - #{exception.message}")
  end

  class BufferError < StandardError; end
end
