class PostContentJob < ApplicationJob
  queue_as :default

  def perform(draft_id)
    draft = DraftContent.find(draft_id)
    return if draft.status == "posted"

    postforme = PostformeService.new
    return unless postforme.configured?

    caption = build_caption(draft)
    media = build_media(draft)
    scheduled_at = draft.scheduled_for

    # Get all profile IDs for the target platform
    profile_ids = get_profile_ids(postforme, draft.platform)

    if profile_ids.empty?
      Rails.logger.warn "[PostContentJob] No connected social accounts found for platform: #{draft.platform}"
      draft.update!(status: 'failed', error_message: 'No connected social accounts found')
      return
    end

    # Post to Postforme
    result = postforme.create_post(profile_ids, caption, media: media, scheduled_at: scheduled_at)

    if result['data'].present?
      platform_post_id = result.dig('data', 'id')
      draft.update!(
        status: scheduled_at.present? ? 'scheduled' : 'posted',
        postforme_post_id: platform_post_id,
        posted_at: scheduled_at.blank? ? Time.current : nil
      )
      Rails.logger.info "[PostContentJob] Post #{draft.id} published via Postforme: #{platform_post_id}"
    else
      error_msg = result.dig('error', 'message') || result.inspect
      draft.update!(status: 'failed', error_message: error_msg)
      Rails.logger.error "[PostContentJob] Failed to post: #{error_msg}"
    end
  rescue PostformeService::PostformeError => e
    draft.update!(status: 'failed', error_message: e.message)
    Rails.logger.error "[PostContentJob] Postforme error: #{e.message}"
  rescue => e
    draft.update!(status: 'failed', error_message: e.message)
    Rails.logger.error "[PostContentJob] Unexpected error: #{e.message}"
  end

  private

  def build_caption(draft)
    caption = draft.content.to_s.dup
    caption = draft.title if caption.blank?
    caption.strip
  end

  def build_media(draft)
    return [] unless draft.media.attached?

    media_urls = []
    if draft.media.image?
      media_urls << { url: draft.media_display_url, type: 'image' }
    elsif draft.media.video?
      media_urls << { url: draft.media_display_url, type: 'video' }
    end
    media_urls
  rescue => e
    Rails.logger.warn "[PostContentJob] Failed to build media: #{e.message}"
    []
  end

  def get_profile_ids(postforme, target_platform)
    accounts = postforme.social_accounts['data'] || []
    platform_map = {
      'twitter' => ['twitter', 'x'],
      'instagram' => ['instagram'],
      'facebook' => ['facebook'],
      'tiktok' => ['tiktok'],
      'linkedin' => ['linkedin'],
      'youtube' => ['youtube'],
      'threads' => ['threads'],
      'bluesky' => ['bluesky'],
      'pinterest' => ['pinterest'],
      'general' => []  # Post to all connected accounts
    }

    target_platforms = platform_map[target_platform&.downcase] || []

    accounts.filter_map do |account|
      account_platform = account['platform']&.downcase
      if target_platforms.empty? || target_platforms.include?(account_platform)
        account['id']
      end
    end
  end
end
