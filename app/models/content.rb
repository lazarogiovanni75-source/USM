class Content < ApplicationRecord
  belongs_to :campaign
  belongs_to :user

  has_many :scheduled_posts, dependent: :destroy

  serialize :media_urls, coder: JSON

  scope :recent, -> { order(created_at: :desc) }
  scope :draft, -> { where(status: 'draft') }
  scope :published, -> { where(status: 'published') }
end
