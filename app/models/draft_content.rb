class DraftContent < ApplicationRecord
  belongs_to :user
  has_many :content_suggestions, dependent: :destroy
  
  validates :title, presence: true
  validates :content_type, presence: true
  validates :platform, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft reviewing approved published pending failed] }
  
  default_scope { order(updated_at: :desc) }
end