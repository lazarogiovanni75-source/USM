# Service to store videos from external URLs to S3 via ActiveStorage
require "open-uri"

class VideoStorageService
  # Store video from external URL to S3
  # @param draft [DraftContent] The draft to attach the video to
  # @param external_url [String] The URL of the video to download
  # @return [Boolean] True if successful
  def self.store_video_from_url(draft, external_url)
    return false if external_url.blank?
    
    # Determine content type based on URL or default to mp4
    content_type = if external_url.end_with?(".mp4")
                      "video/mp4"
                    elsif external_url.end_with?(".webm")
                      "video/webm"
                    elsif external_url.end_with?(".mov")
                      "video/quicktime"
                    elsif external_url.include?("image") || external_url.end_with?(".jpg", ".jpeg", ".png", ".webp")
                      "image/jpeg"
                    else
                      "application/octet-stream"
                    end
    
    # Generate filename
    extension = content_type.split("/").last
    filename = "video_#{draft.id}_#{Time.current.to_i}.#{extension}"
    
    begin
      # Download the file from external URL
      file = URI.open(external_url)
      
      # Attach to draft's media (create attachment if needed)
      draft.media.attach(
        io: file,
        filename: filename,
        content_type: content_type
      )
      
      # Save the draft with the attached file
      if draft.save
        Rails.logger.info "[VideoStorageService] Successfully stored video for draft #{draft.id}"
        true
      else
        Rails.logger.error "[VideoStorageService] Failed to save draft: #{draft.errors.full_messages.join(", ")}"
        false
      end
    rescue => e
      Rails.logger.error "[VideoStorageService] Error storing video: #{e.message}"
      false
    end
  end

  # Store image from external URL to S3
  # @param draft [DraftContent] The draft to attach the image to
  # @param external_url [String] The URL of the image to download
  # @return [Boolean] True if successful
  def self.store_image_from_url(draft, external_url)
    return false if external_url.blank?
    
    content_type = if external_url.end_with?(".png")
                      "image/png"
                    elsif external_url.end_with?(".webp")
                      "image/webp"
                    elsif external_url.end_with?(".gif")
                      "image/gif"
                    else
                      "image/jpeg"
                    end
    
    extension = content_type.split("/").last
    filename = "image_#{draft.id}_#{Time.current.to_i}.#{extension}"
    
    begin
      file = URI.open(external_url)
      
      draft.media.attach(
        io: file,
        filename: filename,
        content_type: content_type
      )
      
      draft.save
    rescue => e
      Rails.logger.error "[VideoStorageService] Error storing image: #{e.message}"
      false
    end
  end

  # Get the CloudFront URL for the attached media
  # @param draft [DraftContent] The draft with attached media
  # @return [String] CloudFront URL or Rails proxy URL
  def self.media_url(draft)
    return nil unless draft.media.attached?
    
    cloudfront_domain = ENV["CLOUDFRONT_DOMAIN"].presence || ENV["CLOUDFRONT_URL"].presence
    
    if cloudfront_domain.present?
      # Use CloudFront URL
      "#{cloudfront_domain}#{Rails.application.routes.url_helpers.rails_blob_path(draft.media, only_path: true)}"
    else
      # Fall back to Rails proxy URL
      Rails.application.routes.url_helpers.rails_blob_url(draft.media, only_path: false)
    end
  end

  # Check if S3 is properly configured
  def self.s3_configured?
    ENV["STORAGE_BUCKET_NAME"].present? && 
    ENV["STORAGE_BUCKET_ACCESS_KEY_ID"].present?
  end
end
