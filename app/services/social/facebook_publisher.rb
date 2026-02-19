# frozen_string_literal: true

# Facebook publisher via Postforme
class Social::FacebookPublisher < Social::PostformePublisher
  PLATFORM = 'facebook'

  def publish(post)
    Rails.logger.info "[FacebookPublisher] Publishing post #{post.id}"

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
    raise PlatformError, "Facebook error: #{e.message}"
  end
end
