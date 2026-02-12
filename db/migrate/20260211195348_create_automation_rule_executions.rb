class CreateAutomationRuleExecutions < ActiveRecord::Migration[7.2]
  def change
    create_table :automation_rule_executions do |t|
      t.references :automation_rule, null: false, foreign_key: true
      t.jsonb :trigger_data, default: {}
      t.string :status, default: 'pending'
      t.jsonb :execution_details, default: {}
      t.text :error_message
      t.timestamps
    end

    add_index :automation_rule_executions, :status
    add_index :automation_rule_executions, :created_at
  end
end
