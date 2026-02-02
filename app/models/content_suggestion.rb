class ContentSuggestion < ApplicationRecord
  belongs_to :user
  belongs_to :draft_content, optional: true
  
  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
  scope :rejected, -> { where(status: 'rejected') }
  
  validates :content_type, presence: true
  validates :topic, presence: true
  validates :suggestion, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending generated accepted rejected] }
end