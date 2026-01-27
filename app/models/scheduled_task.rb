class ScheduledTask < ApplicationRecord
  belongs_to :user
  
  validates :task_type, presence: true
  validates :payload, presence: true
  validates :scheduled_at, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending completed failed running] }
end