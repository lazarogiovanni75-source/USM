# frozen_string_literal: true

class SocialListeningController < ApplicationController
  before_action :authenticate_user!

  def index
    render :coming_soon
  end

  def alerts
    @alerts = current_user.social_listening_alerts.recent

    # Apply filters
    @alerts = @alerts.by_sentiment(params[:sentiment]) if params[:sentiment].present?
    @alerts = @alerts.by_type(params[:type]) if params[:type].present?

    # Unread filter
    @alerts = @alerts.unread if params[:unread] == 'true'

    @alerts = @alerts.limit(100)

    # Stats
    @total_count = current_user.social_listening_alerts.count
    @unread_count = current_user.social_listening_alerts.unread.count
    @sentiment_breakdown = get_sentiment_breakdown
  end

  def mark_read
    alert_ids = params[:alert_ids] || []
    result = SocialListeningService.mark_alerts_read(alert_ids)

    redirect_to social_listening_alerts_path, notice: "#{result[:marked_count]} alerts marked as read"
  end

  def mark_all_read
    current_user.social_listening_alerts.unread.update_all(read_at: Time.current)

    redirect_to social_listening_alerts_path, notice: 'All alerts marked as read'
  end

  def configure
    @keywords = current_user.social_listening_keywords.pluck(:keyword)
    @tracked_hashtags = current_user.social_listening_hashtags.pluck(:hashtag)
  end

  def add_keyword
    keyword = params.dig(:keyword, :term).to_s.strip.presence || params[:keyword].to_s.strip
    return redirect_to social_listening_configure_path, alert: 'Keyword cannot be blank' if keyword.blank?

    current_user.social_listening_keywords.find_or_create_by(keyword: keyword)

    redirect_to social_listening_configure_path, notice: "Keyword '#{keyword}' added"
  end

  def remove_keyword
    keyword = current_user.social_listening_keywords.find_by(keyword: params[:keyword])
    keyword&.destroy

    redirect_to social_listening_configure_path, notice: 'Keyword removed'
  end

  def add_hashtag
    hashtag = params.dig(:hashtag, :tag).to_s.strip.presence || params[:hashtag].to_s.strip
    hashtag = hashtag.start_with?('#') ? hashtag : "##{hashtag}"

    current_user.social_listening_hashtags.find_or_create_by(hashtag: hashtag)

    redirect_to social_listening_configure_path, notice: "Hashtag '#{hashtag}' added"
  end

  def remove_hashtag
    hashtag = current_user.social_listening_hashtags.find_by(hashtag: params[:hashtag])
    hashtag&.destroy

    redirect_to social_listening_configure_path, notice: 'Hashtag removed'
  end

  def refresh_alerts
    # Trigger listening for configured keywords and hashtags
    keywords = current_user.social_listening_keywords.pluck(:keyword)
    hashtags = current_user.social_listening_hashtags.pluck(:hashtag)

    # Listen for keywords
    if keywords.any?
      mentions = SocialListeningService.listen_for_keywords(keywords)
      SocialListeningService.create_alerts(current_user, mentions, 'keyword')
    end

    # Listen for hashtags
    if hashtags.any?
      mentions = SocialListeningService.track_hashtags(hashtags)
      SocialListeningService.create_alerts(current_user, mentions, 'hashtag')
    end

    @unread_count = current_user.social_listening_alerts.unread.count

    redirect_to social_listening_index_path, notice: "Scanned for #{keywords.count} keywords and #{hashtags.count} hashtags. #{@unread_count} new alerts."
  end

  def trends
    keywords = params[:keywords]&.split(',') || current_user.social_listening_keywords.pluck(:keyword)
    days = (params[:days] || 7).to_i

    @trends = SocialListeningService.get_trending_topics(keywords, days)
    @trend_keywords = keywords
    @trend_days = days
  end

  private

  def get_sentiment_breakdown
    alerts = current_user.social_listening_alerts
    {
      positive: alerts.where(sentiment: 'positive').count,
      negative: alerts.where(sentiment: 'negative').count,
      neutral: alerts.where(sentiment: 'neutral').count
    }
  end

  def get_recent_keywords
    current_user.social_listening_alerts
                .recent
                .limit(20)
                .pluck(:keyword)
                .compact
                .uniq
  end
end