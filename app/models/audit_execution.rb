class AuditExecution < ApplicationRecord
  belongs_to :user
  
  # Statuses
  enum :status, {
    pending: 'pending',
    executing: 'executing',
    completed: 'completed',
    failed: 'failed',
    awaiting_confirmation: 'awaiting_confirmation',
    confirmed: 'confirmed',
    rejected: 'rejected'
  }, prefix: true

  # Scopes
  scope :for_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }
  scope :pending_confirmation, -> { where(status: 'awaiting_confirmation') }
  
  # Validations
  validates :tool_name, presence: true
  validates :status, presence: true

  # Parse parameters from JSON
  def parameters=(value)
    super(value.is_a?(Hash) ? value.to_json : value)
  end

  def parameters
    value = super
    return {} if value.blank?
    JSON.parse(value)
  rescue JSON::ParserError
    {}
  end

  # Mark as confirmed (called by user)
  def confirm!
    update!(approved: true, status: 'confirmed')
  end

  # Mark as rejected (called by user)
  def reject!
    update!(approved: false, status: 'rejected')
  end

  # Mark as completed
  def complete!(result = nil)
    update!(
      status: 'completed',
      executed_at: Time.current,
      parameters: parameters.merge(result: result)
    )
  end

  # Mark as failed
  def fail!(error_message)
    update!(
      status: 'failed',
      executed_at: Time.current,
      parameters: parameters.merge(error: error_message)
    )
  end
end
