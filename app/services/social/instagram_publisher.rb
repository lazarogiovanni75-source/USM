# frozen_string_literal: true

# Instagram publisher via Postforme
class Social::InstagramPublisher < Social::PostformePublisher
  PLATFORM = 'instagram'

  def publish(post)
    Rails.logger.info "[InstagramPublisher] Publishing post #{post.id}"

    # Instagram requires specific media handling
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
    raise PlatformError, "Instagram error: #{e.message}"
  end

  private

  def build_media(post)
    media_items = []
    
    if post.respond_to?(:image_url) && post.image_url.present?
      media_items << { url: post.image_url }
    elsif post.respond_to?(:video_url) && post.video_url.present?
      media_items << { url: post.video_url, type: 'video' }
    elsif post.respond_to?(:media_url) && post.media_url.present?
      media_items << { url: post.media_url }
    end

    media_items
  end
end
