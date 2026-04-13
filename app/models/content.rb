class Content < ApplicationRecord
  belongs_to :campaign, optional: true
  belongs_to :user

  has_many :scheduled_posts, dependent: :destroy

  serialize :media_urls, coder: JSON

  # Auto-sync media_url to media_urls for Postforme compatibility
  after_save :sync_media_url_to_media_urls

  scope :recent, -> { order(created_at: :desc) }
  scope :draft, -> { where(status: 'draft') }
  scope :published, -> { where(status: 'published') }

  def published?
    status == 'published'
  end

  private

  def sync_media_url_to_media_urls
    return unless media_url.present?
    return if media_urls.present? && media_urls.is_a?(Array) && media_urls.any?

    # Convert single media_url to media_urls array format
    update_column(:media_urls, [media_url]) if media_url.present?
  end
end