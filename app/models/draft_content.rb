class DraftContent < ApplicationRecord
  belongs_to :user
  has_many :content_suggestions, dependent: :destroy
  
  # ActiveStorage for video/image attachments
  has_one_attached :media
  
  validates :title, presence: true
  validates :content_type, presence: true
  validates :platform, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft reviewing approved published pending failed] }
  
  default_scope { order(updated_at: :desc) }

  # Alias content as body for compatibility with Content model views
  def body
    content
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