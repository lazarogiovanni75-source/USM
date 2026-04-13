# frozen_string_literal: true

# Service for posting content via Postforme API
# Self-hosted Postforme instance
#
# API Documentation: https://api.postforme.dev/docs
class PostformeService
  BASE_URL = 'https://api.postforme.dev/v1'
  TIMEOUT = 30

  def initialize(api_key = nil)
    @api_key = api_key || fetch_api_key
  end

  # ==================== Social Accounts ====================

  # Get list of connected social accounts
  # @param platforms [Array] Optional array of platforms to filter
  # @return [Hash] API response with 'data' key containing array of accounts
  def social_accounts(platforms = [])
    params = platforms&.map { |p| "platform=#{p}" }&.join('&')
    endpoint = params.present? ? "/social-accounts?#{params}" : '/social-accounts'
    get_request(endpoint)
  end

  # Get a single social account by ID
  def social_account(account_id)
    get_request("/social-accounts/#{account_id}")
  end

  # Get social account with metrics
  # @param account_id [String]
  # @return [Hash] Account data with metrics
  def social_account_with_metrics(account_id)
    get_request("/social-accounts/#{account_id}?expand=metrics")
  end

  # Get account analytics/metrics summary
  # @param account_id [String]
  # @return [Hash] Analytics data from account metrics or feed
  def account_metrics(account_id)
    # Try the dedicated metrics endpoint first
    get_request("/social-accounts/#{account_id}/metrics")
  rescue PostformeService::PostformeError
    # Fallback: get metrics from account feed
    account_feed(account_id, expand_metrics: true)
  rescue StandardError
    # Return empty metrics if both endpoints fail
    { 'data' => [] }
  end

  # Generate an OAuth URL for connecting an account
  # @param platform [String] Social platform (instagram, twitter, etc.)
  # @param redirect_uri [String] Optional URL to redirect after OAuth flow
  # @param permissions [Array] Permissions to request (default: ['posts', 'feeds'])
  # @return [Hash] Response with auth_url
  def auth_url(platform, redirect_uri: nil, permissions: ['posts', 'feeds'])
    payload = { platform: platform, permissions: permissions }
    payload[:redirect_uri] = redirect_uri if redirect_uri.present?
    post_request('/social-accounts/auth-url', payload)
  end

  # Get OAuth URL for Postforme connection (initiates OAuth flow)
  # @param redirect_uri [String] URL to redirect after OAuth
  # @return [Hash] Response with auth_url
  def oauth_url(redirect_uri)
    get_request("/oauth/url?redirect_uri=#{CGI.escape(redirect_uri)}")
  rescue PostformeError
    # Fallback: try auth-url endpoint
    { 'url' => "https://app.postforme.dev/oauth/authorize?redirect_uri=#{CGI.escape(redirect_uri)}" }
  end

  # Exchange OAuth code for access token
  # @param code [String] OAuth authorization code
  # @param redirect_uri [String] The redirect URI used in the OAuth flow
  # @return [Hash] Response with access_token
  def oauth_token(code, redirect_uri)
    post_request('/oauth/token', {
      grant_type: 'authorization_code',
      code: code,
      redirect_uri: redirect_uri
    })
  end

  # Disconnect a social account
  def disconnect_account(account_id)
    post_request("/social-accounts/#{account_id}/disconnect", {})
  end

  # ==================== Social Posts ====================

  # List all posts with pagination
  # @param options [Hash] Options for pagination and filtering
  # @option options [Integer] :limit Number of posts per page (default: 20)
  # @option options [Integer] :offset Pagination offset
  # @return [Hash] API response with 'data' and 'meta' keys
  def list_posts(options = {})
    params = []
    params << "limit=#{options[:limit]}" if options[:limit].present?
    params << "offset=#{options[:offset]}" if options[:offset].present?
    endpoint = "/social-posts#{params.any? ? "?#{params.join('&')}" : ''}"
    get_request(endpoint)
  end

  # Create a new post
  # @param social_account_ids [Array] Array of social account IDs to post to
  # @param caption [String] Post caption/text
  # @param options [Hash] Additional options
  # @option options [Array] :media Array of media objects [{ url: string }]
  # @option options [Time, String] :scheduled_at When to schedule the post
  # @option options [Boolean] :now Whether to post immediately (true) or schedule
  def create_post(social_account_ids, caption, options = {})
    payload = {
      caption: caption,
      social_accounts: Array(social_account_ids)
    }
    payload[:media] = Array(options[:media]) if options[:media].present?
    payload[:scheduled_at] = format_scheduled_at(options[:scheduled_at]) if options[:scheduled_at].present?
    payload[:now] = true if options[:now] == true
    post_request('/social-posts', payload)
  end

  # Get a single post by ID
  def get_post(post_id)
    get_request("/social-posts/#{post_id}")
  end

  # Update an existing post
  def update_post(post_id, updates)
    put_request("/social-posts/#{post_id}", updates)
  end

  # Delete a post
  def delete_post(post_id)
    delete_request("/social-posts/#{post_id}")
  end

  # Schedule a post for a specific time
  def schedule_post(social_account_ids, caption, scheduled_at, options = {})
    create_post(social_account_ids, caption, options.merge(scheduled_at: scheduled_at))
  end

  # Share a post immediately
  def share_now(post_id)
    post_request("/social-posts/#{post_id}/share", {})
  end

  # Preview what a post will look like for each account
  def preview_post(post_id)
    post_request("/social-post-previews", { social_post_id: post_id })
  end

  # ==================== Social Post Results ====================

  # Get results for posts (published/failed)
  def post_results(post_id = nil)
    endpoint = post_id ? "/social-post-results/#{post_id}" : '/social-post-results'
    get_request(endpoint)
  end

  # Get analytics for a post
  def post_analytics(post_id)
    get_request("/social-posts/#{post_id}/analytics")
  end

  # ==================== Social Account Feeds ====================

  # Get feed for a social account with optional metrics
  # @param account_id [String] Social account ID
  # @param expand_metrics [Boolean] Whether to include metrics (requires 'feeds' permission)
  # @param limit [Integer] Number of posts to return (default: 50)
  def account_feed(account_id, expand_metrics: false, limit: 50)
    endpoint = "/social-account-feeds/#{account_id}?limit=#{limit}"
    endpoint += "&expand=metrics" if expand_metrics
    get_request(endpoint)
  end

  # ==================== Media ====================

  # Create an upload URL for media files
  # @return [Hash] { upload_url: string, media_url: string }
  def create_upload_url
    post_request('/media/create-upload-url', {})
  end

  # ==================== Webhooks ====================

  # List all webhooks
  def list_webhooks
    get_request('/webhooks')
  end

  # Get a single webhook
  def get_webhook(webhook_id)
    get_request("/webhooks/#{webhook_id}")
  end

  # Create a new webhook
  # @param url [String] URL to receive webhook payloads
  # @param events [Array] Array of event types to subscribe to
  def create_webhook(url, events)
    post_request('/webhooks', { url: url, events: Array(events) })
  end

  # Update a webhook
  def update_webhook(webhook_id, updates)
    patch_request("/webhooks/#{webhook_id}", updates)
  end

  # Delete a webhook
  def delete_webhook(webhook_id)
    delete_request("/webhooks/#{webhook_id}")
  end

  # ==================== Utility ====================

  def configured?
    @api_key.present?
  end

  # Check connection status by testing the API
  # @return [Hash] { status: 'connected'|'error'|'unconfigured', message: String, profiles_count: Integer|nil }
  def connection_status
    return { status: 'unconfigured', message: 'API key not set', profiles_count: 0 } unless configured?

    begin
      response = social_accounts
      profiles = response['data'] || response
      profiles_count = profiles.is_a?(Array) ? profiles.size : 0
      
      {
        status: 'connected',
        message: profiles_count > 0 ? "Connected - #{profiles_count} profile(s)" : 'Connected - No profiles',
        profiles_count: profiles_count
      }
    rescue PostformeService::PostformeError => e
      {
        status: 'error',
        message: "Error: #{e.message}",
        profiles_count: 0
      }
    rescue StandardError => e
      {
        status: 'error',
        message: "Connection failed: #{e.message}",
        profiles_count: 0
      }
    end
  end

  private

  attr_reader :api_key

  def fetch_api_key
    ENV.fetch('POSTFORME_API_KEY') do
      Rails.application.config.x.postforme_api_key ||
        Rails.application.config_for(:application)['POSTFORME_API_KEY']
    end
  rescue KeyError
    Rails.logger.warn('[PostformeService] API key not configured.')
    nil
  end

  def format_scheduled_at(time)
    case time
    when String then time
    when Time, DateTime, ActiveSupport::TimeWithZone then time.iso8601
    else nil
    end
  end

  def headers
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{api_key}"
    }
  end

  def post_request(endpoint, payload)
    url = "#{BASE_URL}#{endpoint}"
    Rails.logger.info("[PostformeService] POST #{url}")
    begin
      response = HTTParty.post(url, body: payload.to_json, headers: headers, timeout: TIMEOUT)
      log_response(response)
      log_body(response)
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
    url = "#{BASE_URL}#{endpoint}"
    Rails.logger.info("[PostformeService] GET #{url}")
    begin
      response = HTTParty.get(url, headers: headers, timeout: TIMEOUT)
      log_response(response)
      log_body(response)
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
    rescue PostformeError => e
      # Don't log 404 errors - they're expected for optional endpoints
      unless e.message.include?("Resource not found")
        log_error(e)
      end
      raise
    rescue StandardError => e
      log_error(e)
      raise PostformeError, "Unknown error: #{e.message}"
    end
  end

  def put_request(endpoint, payload)
    url = "#{BASE_URL}#{endpoint}"
    Rails.logger.info("[PostformeService] PUT #{url}")
    begin
      response = HTTParty.put(url, body: payload.to_json, headers: headers, timeout: TIMEOUT)
      log_response(response)
      log_body(response)
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

  def patch_request(endpoint, payload)
    url = "#{BASE_URL}#{endpoint}"
    Rails.logger.info("[PostformeService] PATCH #{url}")
    begin
      response = HTTParty.patch(url, body: payload.to_json, headers: headers, timeout: TIMEOUT)
      log_response(response)
      log_body(response)
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
    url = "#{BASE_URL}#{endpoint}"
    Rails.logger.info("[PostformeService] DELETE #{url}")
    begin
      response = HTTParty.delete(url, headers: headers, timeout: TIMEOUT)
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
    Rails.logger.info("[PostformeService] Response code: #{response.code}")
  end

  def log_body(response)
    Rails.logger.debug("[PostformeService] Response body: #{response.body}")
  end

  def log_error(exception)
    Rails.logger.error("[PostformeService] Error: #{exception.class} - #{exception.message}")
  end

  class PostformeError < StandardError; end
end
