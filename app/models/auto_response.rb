class AutoResponse < ApplicationRecord
  belongs_to :user
  belongs_to :content, optional: true
  belongs_to :trigger, optional: true
  belongs_to :template, optional: true
  
  # Enums
  enum status: { generated: 'generated', pending_send: 'pending_send', sent: 'sent', failed: 'failed', cancelled: 'cancelled' }
  enum response_type: { comment: 'comment', dm: 'dm', thank_you: 'thank_you', template: 'template' }
  
  # Scopes
  scope :pending_send, -> { where(status: 'pending_send') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_response_type, ->(type) { where(response_type: type) }
  
  # Default values
  before_validation :set_defaults, on: :create
  
  def send_response
    # This would integrate with actual social media APIs
    # For now, we'll simulate sending
    update!(status: 'sent', sent_at: Time.current)
  end
  
  private
  
  def set_defaults
    self.status ||= 'generated'
    self.response_type ||= 'comment'
  end
end