# frozen_string_literal: true

# Controller for managing social posts via Postforme API
class SocialPostsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_service

  def index
    @posts = current_user.social_accounts.joins(:social_posts).distinct
    @api_key = session[:postforme_api_key] || Rails.application.config.x.postforme_api_key
  end

  def list
    options = {}
    options[:limit] = params[:limit].to_i if params[:limit].present?
    options[:offset] = params[:offset].to_i if params[:offset].present?

    begin
      response = @service.list_posts(options)
      @posts = response['data'] || []
      @meta = response['meta'] || {}
    rescue PostformeService::PostformeError => e
      @error = "Failed to fetch posts: #{e.message}"
      @posts = []
      @meta = {}
    end

    render turbo_stream: turbo_stream.replace(
      'social-posts-list',
      partial: 'social_posts/list',
      locals: { posts: @posts, meta: @meta, error: @error }
    )
  end

  def show
    @post = nil
    @error = nil

    begin
      response = @service.get_post(params[:id])
      @post = response['data'] || response
    rescue PostformeService::PostformeError => e
      @error = "Failed to fetch post: #{e.message}"
    end

    render turbo_stream: turbo_stream.replace(
      'social-post-detail',
      partial: 'social_posts/detail',
      locals: { post: @post, error: @error }
    )
  end

  def new
    @accounts = current_user.social_accounts.where.not(postforme_profile_id: nil)
    @api_key = session[:postforme_api_key] || Rails.application.config.x.postforme_api_key
  end

  def create
    caption = params[:caption]
    account_ids = params[:social_account_ids] || []
    scheduled_at = params[:scheduled_at]
    media_urls = params[:media_urls]

    unless caption.present? && account_ids.any?
      redirect_to new_social_post_path, alert: 'Caption and at least one account are required'
      return
    end

    begin
      options = {}
      options[:media] = media_urls.split(',').map(&:strip).reject(&:empty?).map { |url| { url: url } } if media_urls.present?
      options[:scheduled_at] = scheduled_at if scheduled_at.present?

      if params[:schedule_only] == 'true'
        @service.schedule_post(account_ids, caption, scheduled_at, options)
        redirect_to social_posts_path, notice: 'Post scheduled successfully!'
      else
        @service.create_post(account_ids, caption, options.merge(now: true))
        redirect_to social_posts_path, notice: 'Post published successfully!'
      end
    rescue PostformeService::PostformeError => e
      redirect_to new_social_post_path, alert: "Failed to create post: #{e.message}"
    end
  end

  def update
    updates = {}
    updates[:caption] = params[:caption] if params[:caption].present?
    updates[:scheduled_at] = params[:scheduled_at] if params[:scheduled_at].present?

    unless updates.any?
      redirect_to edit_social_post_path(params[:id]), alert: 'No updates provided'
      return
    end

    begin
      @service.update_post(params[:id], updates)
      redirect_to social_post_path(params[:id]), notice: 'Post updated successfully!'
    rescue PostformeService::PostformeError => e
      redirect_to edit_social_post_path(params[:id]), alert: "Failed to update post: #{e.message}"
    end
  end

  def destroy
    begin
      @service.delete_post(params[:id])
      redirect_to social_posts_path, notice: 'Post deleted successfully!'
    rescue PostformeService::PostformeError => e
      redirect_to social_posts_path, alert: "Failed to delete post: #{e.message}"
    end
  end

  def share_now
    begin
      @service.share_now(params[:id])
      redirect_to social_post_path(params[:id]), notice: 'Post is being shared now!'
    rescue PostformeService::PostformeError => e
      redirect_to social_post_path(params[:id]), alert: "Failed to share post: #{e.message}"
    end
  end

  def results
    begin
      response = @service.post_results(params[:id])
      @results = response['data'] || []
    rescue PostformeService::PostformeError => e
      @error = "Failed to fetch results: #{e.message}"
      @results = []
    end

    render turbo_stream: turbo_stream.replace(
      'social-post-results',
      partial: 'social_posts/results',
      locals: { results: @results, error: @error }
    )
  end

  def analytics
    begin
      response = @service.post_analytics(params[:id])
      @analytics = response['data'] || response
    rescue PostformeService::PostformeError => e
      @error = "Failed to fetch analytics: #{e.message}"
      @analytics = nil
    end

    render turbo_stream: turbo_stream.replace(
      'social-post-analytics',
      partial: 'social_posts/analytics',
      locals: { analytics: @analytics, error: @error }
    )
  end

  def account_feed
    account_id = params[:account_id]
    expand_metrics = params[:expand_metrics] == 'true'

    begin
      response = @service.account_feed(account_id, expand_metrics: expand_metrics)
      @feed = response['data'] || response
      @account = current_user.social_accounts.find_by(postforme_profile_id: account_id)
    rescue PostformeService::PostformeError => e
      @error = "Failed to fetch feed: #{e.message}"
      @feed = nil
    end

    render turbo_stream: turbo_stream.replace(
      'social-account-feed',
      partial: 'social_posts/feed',
      locals: { feed: @feed, account: @account, error: @error }
    )
  end

  def preview
    post_id = params[:post_id]

    begin
      response = @service.preview_post(post_id)
      @previews = response['data'] || []
    rescue PostformeService::PostformeError => e
      @error = "Failed to generate previews: #{e.message}"
      @previews = []
    end

    render turbo_stream: turbo_stream.replace(
      'social-post-preview',
      partial: 'social_posts/preview',
      locals: { previews: @previews, error: @error }
    )
  end

  private

  def set_service
    api_key = params[:api_key] || session[:postforme_api_key] || Rails.application.config.x.postforme_api_key
    @service = PostformeService.new(api_key)
  end
end
