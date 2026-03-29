class DraftContent < ApplicationRecord
  belongs_to :user
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
  
  # Get the best URL for displaying media (CloudFront, ActiveStorage, or legacy URL)
  def media_display_url
    # 1. Try ActiveStorage attachment first
    if media.attached?
      cloudfront_domain = ENV["CLACKY_CLOUDFRONT_DOMAIN"].presence
      if cloudfront_domain.present?
        return "#{cloudfront_domain}#{Rails.application.routes.url_helpers.rails_blob_path(media, only_path: true)}"
      end
      return Rails.application.routes.url_helpers.rails_blob_url(media, only_path: false)
    end
    
    # 2. Fall back to legacy media_url field
    media_url
  end
  
  private
  
  def generate_approval_token
    self.approval_token = SecureRandom.urlsafe_base64(32)
  end
  
  # Get the best URL for displaying media (CloudFront, ActiveStorage, or legacy URL)
  def media_display_url
    # 1. Try ActiveStorage attachment first
    if media.attached?
      cloudfront_domain = ENV["CLACKY_CLOUDFRONT_DOMAIN"].presence
      if cloudfront_domain.present?
        return "#{cloudfront_domain}#{Rails.application.routes.url_helpers.rails_blob_path(media, only_path: true)}"
      end
      return Rails.application.routes.url_helpers.rails_blob_url(media, only_path: false)
    end
    
    # 2. Fall back to legacy media_url field
    media_url
  end
end