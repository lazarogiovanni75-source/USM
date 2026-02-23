class AutomationRule < ApplicationRecord
  belongs_to :user
  has_many :rule_executions, class_name: 'AutomationRuleExecution', foreign_key: :automation_rule_id, dependent: :destroy
  
  scope :active, -> { where(is_active: true) }
  
  validates :name, presence: true
  validates :trigger_type, presence: true
  validates :action_type, presence: true
  validates :conditions, presence: true
  validates :actions, presence: true
  
  def active?
    is_active?
  end
end