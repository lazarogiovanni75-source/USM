# frozen_string_literal: true

# TikTok publisher via Postforme
class Social::TiktokPublisher < Social::PostformePublisher
  PLATFORM = 'tiktok'

  def publish(post)
    Rails.logger.info "[TiktokPublisher] Publishing post #{post.id}"

    # TikTok primarily uses video
    caption = build_caption(post)
    media = build_media(post)

    result = postforme_service.create_post(
      profile_id,
      caption,
      media: media,
      now: true
    )

    handle_result(result, post)
  rescue PostformeService::PostformeError => e
    raise PlatformError, "TikTok error: #{e.message}"
  end
end
