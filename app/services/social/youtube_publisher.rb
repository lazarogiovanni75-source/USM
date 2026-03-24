# frozen_string_literal: true

# YouTube publisher via Postforme
class Social::YoutubePublisher < Social::PostformePublisher
  PLATFORM = 'youtube'

  def publish(post)
    Rails.logger.info "[YoutubePublisher] Publishing post #{post.id}"

    # YouTube requires video
    unless post.respond_to?(:video_url) && post.video_url.present?
      raise PlatformError, "YouTube requires video URL"
    end

    result = postforme_service.create_post(
      profile_id,
      post.title.to_s,
      media: [{ url: post.video_url }],
      now: true
    )

    handle_result(result, post)
  rescue PostformeService::PostformeError => e
    raise PlatformError, "YouTube error: #{e.message}"
  end
end
