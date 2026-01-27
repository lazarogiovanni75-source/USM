class DraftContent < ApplicationRecord
  belongs_to :user
  
  validates :title, presence: true
  validates :content_type, presence: true
  validates :platform, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft reviewing approved published] }
  
  default_scope { order(updated_at: :desc) }
end