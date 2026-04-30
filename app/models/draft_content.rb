class DraftContent < ApplicationRecord
  include QualityTiers

  belongs_to :user
  belongs_to :campaign, optional: true
  has_many :content_suggestions, dependent: :destroy
  
  # ActiveStorage for video/image attachments
  has_one_attached :media
  
  validates :title, presence: true
  validates :content_type, presence: true
  validates :platform, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft reviewing approved published pending failed rejected] }
  
  before_create :generate_approval_token
  
  default_scope { order(updated_at: :desc) }

  # Alias content as body for compatibility with Content model views
  def body
    content
  end
  
  # Approval status methods
  def pending? = status == 'pending'
  def approved? = status == 'approved'
  def rejected? = status == 'rejected'
  
  def approve!
    update!(status: 'approved')
  end
  
  def mark_rejected!
    update!(status: 'rejected')
  end
  
  def mark_posted!
    update!(status: 'posted', posted_at: Time.current)
  end

  # Check if content was successfully posted to social media
  def posted_successfully?
    status == 'posted' && postforme_post_id.present?
  end

  # Get the Postforme post URL if available
  def postforme_url
    return nil unless postforme_post_id
    "https://app.postforme.dev/posts/#{postforme_post_id}"
  end
  
  # Quality tier helpers
  def hd?
    quality_tier == 'hd'
  end

  def quality_badge
    return nil unless hd?
    'HD'
  end

  # Get the best URL for displaying media (CloudFront, ActiveStorage, or legacy URL)
  def media_display_url
    # 1. Try ActiveStorage attachment first
    if media.attached?
      begin
        cloudfront_domain = ENV["CLOUDFRONT_DOMAIN"].presence
        if cloudfront_domain.present?
          return "#{cloudfront_domain}#{Rails.application.routes.url_helpers.rails_blob_path(media, only_path: true)}"
        end
        return Rails.application.routes.url_helpers.rails_blob_url(media, only_path: false)
      rescue Aws::S3::Errors::AccessDenied, Aws::S3::Errors::Forbidden => e
        Rails.logger.warn "S3 access denied for media #{id}: #{e.message}"
        return nil  # Return nil to trigger placeholder in views
      rescue StandardError => e
        Rails.logger.error "Failed to generate media URL for #{id}: #{e.message}"
        return nil
      end
    end
    
    # 2. Check if legacy media_url is an expired cloud storage URL
    if media_url.present?
      url = media_url.downcase
      # Alibaba Cloud OSS URLs typically expire and cause "Request has expired" errors
      # Skip these and return nil to show placeholder instead of broken image
      if url.include?('aliyuncs.com') || url.include?('oss-') || url.include?('dashscope')
        Rails.logger.info "Skipping expired Alibaba Cloud URL for draft #{id}"
        return nil
      end
      return media_url
    end
    
    nil
  end
  
  private
  
  def generate_approval_token
    self.approval_token = SecureRandom.urlsafe_base64(32)
  end
end