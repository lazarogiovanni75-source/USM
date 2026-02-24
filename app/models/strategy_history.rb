class StrategyHistory < ApplicationRecord
  belongs_to :user
  
  validates :focus_area, presence: true
  validates :overall_score, numericality: { only_integer: true, in: 0..100 }
  
  scope :by_user, ->(user) { where(user_id: user.id) if user }
  scope :recent, -> { order(generated_at: :desc) }
  scope :by_focus_area, ->(area) { where(focus_area: area) if area }
end
