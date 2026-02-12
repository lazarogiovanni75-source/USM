class AutomationRuleExecution < ApplicationRecord
  belongs_to :automation_rule

  enum status: {
    pending: 'pending',
    executed: 'executed',
    failed: 'failed'
  }
end
