class AutoResponseTrigger < ApplicationRecord
  belongs_to :user
  
  validates :name, presence: true
  validates :trigger_type, presence: true
  validates :response_type, presence: true
  
  # Serialized fields
  serialize :conditions, Array
  serialize :config, JSON
  
  # Enums
  enum status: { active: 'active', inactive: 'inactive' }
  enum trigger_type: { 
    comment_received: 'comment_received',
    like_received: 'like_received',
    dm_received: 'dm_received',
    share_received: 'share_received',
    mention_received: 'mention_received',
    high_engagement: 'high_engagement'
  }
  enum response_type: {
    ai_comment: 'ai_comment',
    ai_dm: 'ai_dm',
    auto_like: 'auto_like',
    auto_follow: 'auto_follow',
    ai_thank_you: 'ai_thank_you',
    custom_template: 'custom_template'
  }
  
  # Associations
  has_many :trigger_executions, dependent: :destroy
  has_many :auto_responses, dependent: :destroy
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_trigger_type, ->(type) { where(trigger_type: type) }
  
  # Default values
  before_validation :set_defaults, on: :create
  
  def active?
    status == 'active'
  end
  
  private
  
  def set_defaults
    self.status ||= 'active'
    self.conditions ||= []
    self.config ||= {}
  end
end