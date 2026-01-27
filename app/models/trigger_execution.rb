class TriggerExecution < ApplicationRecord
  belongs_to :auto_response_trigger, foreign_key: :trigger_id
  belongs_to :user
  
  # Serialized fields
  serialize :engagement_data, JSON
  serialize :response_data, JSON
  
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