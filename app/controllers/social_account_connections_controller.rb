# frozen_string_literal: true

# Controller for connecting social media accounts via Postforme API
class SocialAccountConnectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_service, only: [:available_profiles, :connect_profile, :disconnect_account]

  def index
    @accounts = current_user.social_accounts.order(platform: :asc)
    @api_key = session[:postforme_api_key] || Rails.application.config.x.postforme_api_key
  end

  def update_api_key
    api_key = params[:api_key]

    unless api_key.present?
      redirect_to social_account_connections_path, alert: 'API key is required'
      return
    end

    # Test the API key by fetching profiles
    service = PostformeService.new(api_key)

    begin
      response = service.social_accounts
      profiles = response['data'] || response

      if profiles.present?
        session[:postforme_api_key] = api_key
        redirect_to social_account_connections_path,
                   notice: 'API key verified! You can now connect your social accounts.'
      else
        redirect_to social_account_connections_path,
                   alert: 'API key is valid but no profiles found.'
      end
    rescue PostformeService::PostformeError => e
      redirect_to social_account_connections_path,
                 alert: "Invalid API key: #{e.message}"
    end
  end

  def available_profiles
    api_key = params[:api_key] || session[:postforme_api_key]

    unless api_key.present?
      @error = 'API key is required'
      render turbo_stream: turbo_stream.replace(
        'profiles-list',
        partial: 'social_account_connections/profiles_list',
        locals: { profiles: [], error: @error, api_key: nil }
      )
      return
    end

    begin
      @profiles = @service.fetch_available_profiles(api_key)
      render turbo_stream: turbo_stream.replace(
        'profiles-list',
        partial: 'social_account_connections/profiles_list',
        locals: { profiles: @profiles, error: nil, api_key: api_key }
      )
    rescue PostformeService::PostformeError => e
      Rails.logger.error("[SocialAccountConnections] Error fetching profiles: #{e.message}")
      @error = "Failed to fetch profiles: #{e.message}"
      render turbo_stream: turbo_stream.replace(
        'profiles-list',
        partial: 'social_account_connections/profiles_list',
        locals: { profiles: [], error: @error, api_key: nil }
      )
    rescue StandardError => e
      Rails.logger.error("[SocialAccountConnections] Error fetching profiles: #{e.message}")
      @error = "Failed to fetch profiles: #{e.message}"
      render turbo_stream: turbo_stream.replace(
        'profiles-list',
        partial: 'social_account_connections/profiles_list',
        locals: { profiles: [], error: @error, api_key: nil }
      )
    end
  end

  def connect_profile
    api_key = params[:api_key] || session[:postforme_api_key]
    profile_id = params[:profile_id]
    platform = params[:platform]

    unless api_key.present? && profile_id.present? && platform.present?
      redirect_to social_account_connections_path, alert: 'Missing required parameters'
      return
    end

    begin
      # Get profile details from Postforme
      profile = @service.fetch_available_profiles(api_key).find { |p| p[:id] == profile_id }

      unless profile
        redirect_to social_account_connections_path, alert: 'Profile not found'
        return
      end

      # Check if account already exists
      existing_account = current_user.social_accounts.find_by(
        platform: platform,
        postforme_profile_id: profile_id
      )

      if existing_account
        # Update existing account
        existing_account.update!(
          account_name: profile[:name],
          postforme_api_key: api_key
        )
        message = 'Account updated successfully!'
      else
        # Create new account
        current_user.social_accounts.create!(
          account_name: profile[:name],
          platform: platform,
          postforme_api_key: api_key,
          postforme_profile_id: profile_id
        )
        message = 'Account connected successfully!'
      end

      redirect_to social_account_connections_path, notice: message
    rescue StandardError => e
      Rails.logger.error("[SocialAccountConnections] Error connecting profile: #{e.message}")
      redirect_to social_account_connections_path,
                 alert: "Failed to connect account: #{e.message}"
    end
  end

  def disconnect_account
    account = current_user.social_accounts.find(params[:id])

    unless account
      redirect_to social_account_connections_path, alert: 'Account not found'
      return
    end

    begin
      account.update!(
        postforme_api_key: nil,
        postforme_profile_id: nil,
        likes: nil,
        views: nil,
        engagement: nil,
        shares: nil,
        followers: nil,
        new_followers: nil,
        unfollowers: nil,
        messages: nil
      )

      redirect_to social_account_connections_path, notice: 'Account disconnected successfully.'
    rescue StandardError => e
      redirect_to social_account_connections_path,
                 alert: "Failed to disconnect account: #{e.message}"
    end
  end

  # Initiate OAuth flow with Postforme
  def initiate_oauth
    begin
      service = PostformeService.new
      redirect_uri = postforme_oauth_callback_url
      
      # Get OAuth URL from Postforme
      response = service.oauth_url(redirect_uri)
      auth_url = response['url'] || response['auth_url']
      
      if auth_url
        # Store state for security
        state = SecureRandom.hex(16)
        session[:postforme_oauth_state] = state
        session[:postforme_oauth_initiated_at] = Time.current.to_i
        
        # Redirect to Postforme OAuth
        redirect_to "#{auth_url}&state=#{state}", allow_other_host: true
      else
        redirect_to social_account_connections_path, alert: 'Failed to get OAuth URL from Postforme'
      end
    rescue PostformeService::PostformeError => e
      Rails.logger.error("[Postforme OAuth] Error: #{e.message}")
      redirect_to social_account_connections_path, alert: "OAuth Error: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("[Postforme OAuth] Error: #{e.message}")
      redirect_to social_account_connections_path, alert: "Error: #{e.message}"
    end
  end

  # Handle OAuth callback from Postforme
  def oauth_callback
    error = params[:error]
    error_description = params[:error_description]
    code = params[:code]
    state = params[:state]
    
    # Verify state to prevent CSRF
    stored_state = session[:postforme_oauth_state]
    stored_time = session[:postforme_oauth_initiated_at]
    
    if error
      redirect_to social_account_connections_path, alert: "OAuth Error: #{error_description || error}"
      return
    end
    
    if state != stored_state
      redirect_to social_account_connections_path, alert: 'OAuth state mismatch. Please try again.'
      return
    end
    
    # Check if state expired (15 minutes)
    if stored_time && (Time.current.to_i - stored_time > 900)
      redirect_to social_account_connections_path, alert: 'OAuth session expired. Please try again.'
      return
    end
    
    begin
      # Exchange code for token
      service = PostformeService.new
      redirect_uri = postforme_oauth_callback_url
      token_response = service.oauth_token(code, redirect_uri)
      
      access_token = token_response['access_token'] || token_response['token']
      
      unless access_token
        redirect_to social_account_connections_path, alert: 'Failed to get access token'
        return
      end
      
      # Store the API key in session
      session[:postforme_api_key] = access_token
      
      # Clear OAuth state
      session.delete(:postforme_oauth_state)
      session.delete(:postforme_oauth_initiated_at)
      
      redirect_to social_account_connections_path, notice: 'Successfully connected to Postforme!'
    rescue PostformeService::PostformeError => e
      Rails.logger.error("[Postforme OAuth] Token exchange error: #{e.message}")
      redirect_to social_account_connections_path, alert: "Failed to complete OAuth: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("[Postforme OAuth] Error: #{e.message}")
      redirect_to social_account_connections_path, alert: "Error: #{e.message}"
    end
  end

  # Share content directly to a connected social media account
  def share_to_social_media
    draft_id = params[:draft_id]
    social_account_id = params[:social_account_id]

    unless draft_id.present? && social_account_id.present?
      redirect_to draft_path(draft_id), alert: 'Missing draft or social account'
      return
    end

    draft = current_user.draft_contents.find_by(id: draft_id)
    unless draft
      redirect_to drafts_path, alert: 'Draft not found'
      return
    end

    social_account = current_user.social_accounts.find_by(id: social_account_id)
    unless social_account
      redirect_to draft_path(draft), alert: 'Social account not found'
      return
    end

    begin
      service = PostformeService.new(social_account.postforme_api_key)

      # Prepare content text (caption)
      caption = draft.content.presence || draft.title

      # Prepare media if available
      options = {}
      if draft.media_url.present?
        options[:media] = [{ url: draft.media_url }]
      end

      # Post to Postforme using new API format
      response = service.create_post(
        [social_account.postforme_profile_id],
        caption,
        options.merge(now: true)
      )

      if response.present? && (response['success'] || response['data'] || response['post'] || response['id'])
        # Create a record of this share
        content = current_user.contents.create!(
          title: draft.title,
          body: caption,
          content_type: draft.content_type,
          platform: social_account.platform,
          status: 'published'
        )

        # Update draft status
        draft.update(status: 'published')

        # Extract Postforme post ID if available
        postforme_post_id = response.dig('data', 'id') || response.dig('post', 'id') || response.dig('id')

        redirect_to draft_path(draft), notice: "Successfully posted to #{social_account.name || social_account.platform.titleize}!"
      else
        redirect_to draft_path(draft), alert: 'Failed to post to social media. Please try again.'
      end
    rescue PostformeService::PostformeError => e
      Rails.logger.error("[SocialAccountConnections] Share error: #{e.message}")
      redirect_to draft_path(draft), alert: "Failed to post: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("[SocialAccountConnections] Share error: #{e.message}")
      redirect_to draft_path(draft), alert: "Failed to post: #{e.message}"
    end
  end

  private

  def set_service
    @service = PostformeDashboardService.new
  end

  def postforme_oauth_callback_url
    auth_postforme_callback_url
  end
end
