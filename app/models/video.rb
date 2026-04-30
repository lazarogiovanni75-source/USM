class Video < ApplicationRecord
  belongs_to :user
  has_one_attached :media
  
  # Validates
  validates :user, presence: true
  
  # Status enum
  enum :status, { pending: 'pending', processing: 'processing', completed: 'completed', failed: 'failed' }, prefix: true
end
