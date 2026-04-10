class OttoMessage < ApplicationRecord
  belongs_to :user

  validates :role, inclusion: { in: %w[user assistant] }
  validates :content, presence: true

  scope :recent, -> { order(created_at: :asc).last(20) }
end
