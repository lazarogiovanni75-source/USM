class ZapierWebhook < ApplicationRecord
  belongs_to :user
  
  validates :webhook_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
  validates :name, presence: true
  validates :event_type, presence: true
  
  # Default values
  before_validation :set_defaults, on: :create
  
  private
  
  def set_defaults
    self.trigger_events ||= []
    self.config ||= {}
    self.status ||= 'active'
    self.endpoint_id ||= SecureRandom.uuid
  end
end