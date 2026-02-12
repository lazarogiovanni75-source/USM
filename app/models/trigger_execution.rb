class TriggerExecution < ApplicationRecord
  belongs_to :auto_response_trigger
  belongs_to :user
  
  # Enums
  enum status: { executed: 'executed', failed: 'failed', skipped: 'skipped' }
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: 'executed') }
  scope :failed, -> { where(status: 'failed') }
  
  # Default values
  before_validation :set_defaults, on: :create
  
  private
  
  def set_defaults
    self.status ||= 'executed'
  end
end