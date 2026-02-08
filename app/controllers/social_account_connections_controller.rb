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
      profiles = service.profiles

      if profiles.present?
        # Save API key to user's settings (you may want to add this field to User model)
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
      render :profiles_error
      return
    end

    begin
      @profiles = @service.fetch_available_profiles(api_key)
      render :available_profiles
    rescue StandardError => e
      Rails.logger.error("[SocialAccountConnections] Error fetching profiles: #{e.message}")
      @error = 'Failed to fetch profiles. Please check your API key.'
      render turbo_stream: turbo_stream.replace(
        'profiles-list',
        partial: 'social_account_connections/profiles_list',
        locals: { profiles: [], error: @error }
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
          name: profile[:name],
          postforme_api_key: api_key,
          username: profile[:username]
        )
        message = 'Account updated successfully!'
      else
        # Create new account
        current_user.social_accounts.create!(
          name: profile[:name],
          platform: platform,
          postforme_api_key: api_key,
          postforme_profile_id: profile_id,
          username: profile[:username]
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

      # Prepare content text
      text = draft.content.presence || draft.title

      # Prepare media if available
      options = {}
      if draft.media_url.present?
        options[:media] = { url: draft.media_url }
      end

      # Post to Postforme
      response = service.create_post(social_account.postforme_profile_id, text, options.merge(now: true))

      if response.present? && (response['success'] || response['post'] || response['id'])
        # Create a record of this share
        content = current_user.contents.create!(
          title: draft.title,
          body: text,
          content_type: draft.content_type,
          platform: social_account.platform,
          status: 'published'
        )

        # Update draft status
        draft.update(status: 'published')

        # Extract Postforme post ID if available
        postforme_post_id = response.dig('post', 'id') || response.dig('id') || response['data']&.dig('id')

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
end
