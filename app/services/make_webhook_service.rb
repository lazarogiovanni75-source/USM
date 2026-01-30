# frozen_string_literal: true

# Service for sending webhook notifications to Make (Integromat)
# when social posts are created or scheduled.
#
# This service is solely responsible for:
# - Sending HTTP POST requests to Make webhooks
# - Logging success/failure of webhook deliveries
# - NOT handling OAuth or direct platform connections
class MakeWebhookService
  WEBHOOK_URL_CONFIG_KEY = 'MAKE_WEBHOOK_URL'

  def initialize(scheduled_post)
    @scheduled_post = scheduled_post
    @webhook_url = fetch_webhook_url
  end

  # Sends webhook payload for a newly created or scheduled post
  # Returns true if webhook was sent successfully, false otherwise
  def trigger_post_created
    return false unless webhook_configured?

    payload = build_payload
    send_webhook_request(payload)
  end

  # Alias for trigger_post_created for semantic clarity
  def trigger_post_scheduled
    trigger_post_created
  end

  private

  attr_reader :scheduled_post, :webhook_url

  def webhook_configured?
    webhook_url.present? && webhook_url != ''
  end

  def fetch_webhook_url
    ENV.fetch(WEBHOOK_URL_CONFIG_KEY) do
      Rails.application.config.x.send(WEBHOOK_URL_CONFIG_KEY.downcase) ||
        Rails.application.config.x.make_webhook_url ||
        Rails.application.config_for(:application)[WEBHOOK_URL_CONFIG_KEY]
    end
  rescue KeyError
    Rails.logger.warn("[MakeWebhookService] Webhook URL not configured. Set #{WEBHOOK_URL_CONFIG_KEY} in environment or config.")
    nil
  end

  def build_payload
    user = scheduled_post.user
    content = scheduled_post.content
    social_account = scheduled_post.social_account

    {
      user_id: user.id,
      text: extract_caption(content),
      image_url: extract_image_url(content),
      platform: extract_platform(social_account),
      schedule_time: scheduled_post.scheduled_at&.iso8601
    }
  end

  def extract_caption(content)
    return nil if content.nil?
    content.body.presence || content.title.presence || content.caption.presence
  end

  def extract_image_url(content)
    return nil if content.nil?
    return nil if content.media_urls.blank?

    media_urls = content.media_urls
    return nil if media_urls.empty?

    case media_urls
    when String
      JSON.parse(media_urls)&.first
    when Array
      media_urls.first
    when Hash
      media_urls['urls']&.first || media_urls.values.first
    else
      nil
    end
  end

  def extract_platform(social_account)
    return nil if social_account.nil?
    social_account.platform
  end

  def send_webhook_request(payload)
    Rails.logger.info("[MakeWebhookService] Sending webhook for scheduled_post #{scheduled_post.id}")

    begin
      response = HTTParty.post(
        webhook_url,
        body: payload.to_json,
        headers: {
          'Content-Type' => 'application/json',
          'User-Agent' => "UltimateSocialMedia/#{Rails.env}"
        },
        timeout: 30
      )

      log_webhook_result(response, payload)
      response.success?
    rescue HTTParty::Error => e
      log_webhook_error(e, payload, 'HTTParty error')
      false
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => e
      log_webhook_error(e, payload, 'Connection timeout')
      false
    rescue SocketError, Errno::ECONNREFUSED => e
      log_webhook_error(e, payload, 'Connection refused')
      false
    rescue StandardError => e
      log_webhook_error(e, payload, 'Unknown error')
      false
    end
  end

  def log_webhook_result(response, payload)
    status = response.success? ? 'SUCCESS' : 'FAILURE'
    message = "[MakeWebhookService] Webhook #{status}: post_id=#{scheduled_post.id}, status=#{response.code}"

    if response.success?
      Rails.logger.info(message)
    else
      Rails.logger.warn("#{message}, response_body=#{response.body&.slice(0, 500)}")
    end

    Rails.logger.debug("[MakeWebhookService] Payload sent: #{payload.except(:user_id).inspect}")
  end

  def log_webhook_error(exception, payload, error_type)
    Rails.logger.error("[MakeWebhookService] Webhook ERROR (#{error_type}): post_id=#{scheduled_post.id}, message=#{exception.message}")
    Rails.logger.debug("[MakeWebhookService] Failed payload: #{payload.except(:user_id).inspect}")
  end
end
