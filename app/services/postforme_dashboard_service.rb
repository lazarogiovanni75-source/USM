# frozen_string_literal: true

# Service for fetching social media metrics from Postforme API
# Aggregates profile-level analytics for the social media dashboard
class PostformeDashboardService
  PLATFORM_MAPPING = {
    'instagram' => 'instagram',
    'twitter' => 'twitter',
    'x' => 'twitter',
    'facebook' => 'facebook',
    'linkedin' => 'linkedin',
    'tiktok' => 'tiktok',
    'youtube' => 'youtube',
    'pinterest' => 'pinterest',
    'bluebird' => 'bluebird',
    'threads' => 'threads'
  }.freeze

  def initialize(social_account = nil)
    @social_account = social_account
    @postforme_service = nil
  end

  # Fetch metrics for a social account from Postforme
  # @param account [SocialAccount]
  # @return [Hash] Metrics data
  # Fetch metrics for a social account from Postforme
  # @param account [SocialAccount]
  # @return [Hash] Metrics data
  def fetch_account_metrics(account)
    return empty_metrics unless account.configured_for_postforme?

    begin
      profile_id = account.postforme_profile_id
      
      # Get account profile data
      profile_data = postforme_service(account).social_account(profile_id)
      
      # Get metrics from recent posts (aggregate)
      metrics_data = postforme_service(account).account_metrics(profile_id)
      
      # Extract metrics from posts
      post_metrics = extract_post_metrics(metrics_data)
      
      {
        connected: true,
        platform: account.platform,
        name: profile_data['username'] || profile_data['name'] || account.account_name || account.platform.titleize,
        profile_id: profile_id,
        followers: account.followers || 0,  # Use stored value or fallback
        likes: post_metrics[:likes],
        views: post_metrics[:views],
        engagement: post_metrics[:engagement],
        shares: post_metrics[:shares],
        new_followers: 0,  # Postforme doesn't track this
        unfollowers: 0,   # Postforme doesn't track this
        messages: 0,      # Postforme doesn't track this
        posts_count: post_metrics[:posts_count],
        last_synced: Time.current
      }
    rescue PostformeService::PostformeError => e
      Rails.logger.error("[PostformeDashboard] API error for account #{account.id}: #{e.message}")
      # Fallback to stored metrics when API fails
      fallback_metrics(account)
    rescue StandardError => e
      Rails.logger.error("[PostformeDashboard] Error fetching metrics: #{e.message}")
      # Fallback to stored metrics when any error occurs
      fallback_metrics(account)
    end
  end

  # Fallback to stored metrics when Postforme API fails
  def fallback_metrics(account)
    {
      connected: false,
      platform: account.platform,
      name: account.account_name || account.platform.titleize,
      profile_id: account.postforme_profile_id,
      followers: account.followers || 0,
      likes: account.likes || 0,
      views: account.views || 0,
      engagement: account.engagement || 0,
      shares: account.shares || 0,
      new_followers: account.new_followers || 0,
      unfollowers: account.unfollowers || 0,
      messages: account.messages || 0,
      posts_count: 0,
      last_synced: account.metrics_synced_at,
      error: 'Using cached metrics'
    }
  end

  # Extract metrics from posts array
  def extract_post_metrics(metrics_data)
    posts = metrics_data['data'] || metrics_data || []
    
    total_likes = 0
    total_views = 0
    total_engagement = 0
    total_shares = 0
    posts_count = posts.length
    
    posts.each do |post|
      post_metrics = post['metrics'] || {}
      total_likes += post_metrics['likes'].to_i
      total_views += post_metrics['views'].to_i
      total_engagement += post_metrics['total_interactions'].to_i
      total_shares += post_metrics['shares'].to_i
    end
    
    {
      likes: total_likes,
      views: total_views,
      engagement: total_engagement,
      shares: total_shares,
      posts_count: posts_count
    }
  end

  # Fetch all profiles from Postforme (for account connection)
  # @param api_key [String] Postforme API key
  # @return [Array] List of available profiles
  def fetch_available_profiles(api_key)
    service = PostformeService.new(api_key)
    response = service.social_accounts

    Array(response['data'] || response).map do |account|
      {
        id: account['id'],
        name: account['name'] || account['username'] || account['handle'],
        platform: map_platform(account['platform']),
        username: account['username'] || account['handle'],
        avatar_url: account['avatar'] || account['avatar_url'],
        followers: account['followers'] || account['follower_count'],
        connected: false
      }
    end
  rescue PostformeService::PostformeError => e
    raise e
  end

  # Sync metrics from Postforme to SocialAccount
  # @param account [SocialAccount]
  # @return [Boolean] Success status
  def sync_account_metrics(account)
    metrics = fetch_account_metrics(account)

    return false unless metrics[:connected]

    account.update!(
      likes: metrics[:likes],
      views: metrics[:views],
      engagement: metrics[:engagement],
      shares: metrics[:shares],
      followers: metrics[:followers],
      new_followers: metrics[:new_followers],
      unfollowers: metrics[:unfollowers],
      messages: metrics[:messages],
      metrics_synced_at: Time.current
    )

    true
  end

  # Calculate aggregated metrics for a user from their social accounts
  # @param user [User]
  # @return [Hash] Aggregated metrics
  def aggregate_user_metrics(user)
    accounts = user.social_accounts.where.not(postforme_profile_id: nil)

    total_metrics = accounts.reduce(empty_metrics) do |sum, account|
      metrics = fetch_account_metrics(account)
      next sum unless metrics[:connected]

      {
        likes: sum[:likes] + metrics[:likes].to_i,
        views: sum[:views] + metrics[:views].to_i,
        engagement: sum[:engagement] + metrics[:engagement].to_i,
        shares: sum[:shares] + metrics[:shares].to_i,
        followers: sum[:followers] + metrics[:followers].to_i,
        new_followers: sum[:new_followers] + metrics[:new_followers].to_i,
        unfollowers: sum[:unfollowers] + metrics[:unfollowers].to_i,
        messages: sum[:messages] + metrics[:messages].to_i
      }
    end

    {
      total_likes: total_metrics[:likes],
      total_views: total_metrics[:views],
      total_engagement: total_metrics[:engagement],
      total_shares: total_metrics[:shares],
      total_followers: total_metrics[:followers],
      total_new_followers: total_metrics[:new_followers],
      total_unfollowers: total_metrics[:unfollowers],
      total_messages: total_metrics[:messages],
      connected_accounts: accounts.count,
      last_synced: Time.current
    }
  end

  # Check if Postforme is properly configured
  def configured?
    postforme_service&.configured?
  end

  private

  attr_reader :social_account

  def postforme_service(account = nil)
    account ||= social_account
    return nil unless account&.configured_for_postforme?

    PostformeService.new(account.postforme_api_key)
  end

  def empty_metrics
    {
      connected: false,
      platform: nil,
      name: nil,
      profile_id: nil,
      followers: 0,
      likes: 0,
      views: 0,
      engagement: 0,
      shares: 0,
      new_followers: 0,
      unfollowers: 0,
      messages: 0,
      posts_count: 0,
      last_synced: nil,
      error: nil
    }
  end

  def extract_followers(profile_data, analytics_data)
    # Try various field names for followers
    profile_data['followers'] ||
      profile_data['follower_count'] ||
      profile_data['followers_count'] ||
      analytics_data['followers'] ||
      analytics_data['total_followers'] ||
      0
  end

  def extract_metric(data, key)
    return 0 if data.nil?

    value = data[key]
    value&.to_i
  end

  def map_platform(service_name)
    return nil if service_name.nil?

    PLATFORM_MAPPING[service_name.downcase] || service_name.downcase
  end
end
