class ScheduledPost < ApplicationRecord
  belongs_to :content
  belongs_to :social_account
  belongs_to :user
  has_many :performance_metrics, dependent: :destroy
end
