class ContentSuggestion < ApplicationRecord
  belongs_to :user
  
  validates :content_type, presence: true
  validates :topic, presence: true
  validates :suggestion, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending generated accepted rejected] }
end