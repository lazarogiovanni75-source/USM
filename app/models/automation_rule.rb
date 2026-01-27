class AutomationRule < ApplicationRecord
  belongs_to :user
  
  validates :name, presence: true
  validates :trigger_type, presence: true
  validates :action_type, presence: true
  validates :conditions, presence: true
  validates :actions, presence: true
end