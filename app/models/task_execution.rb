class TaskExecution < ApplicationRecord
  belongs_to :scheduled_ai_task
  belongs_to :user
  
  # Enums
  enum status: { executed: 'executed', failed: 'failed', cancelled: 'cancelled' }
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: 'executed') }
  scope :failed, -> { where(status: 'failed') }
  
  # Default values
  before_validation :set_defaults, on: :create
  
  private
  
  def set_defaults
    self.status ||= 'executed'
    self.started_at ||= Time.current
  end
end