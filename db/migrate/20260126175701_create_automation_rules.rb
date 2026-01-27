class CreateAutomationRules < ActiveRecord::Migration[7.2]
  def change
    create_table :automation_rules, force: true do |t|
      t.belongs_to :user, null: false
      t.string :name
      t.string :trigger_type
      t.string :action_type
      t.json :conditions
      t.json :actions
      t.boolean :is_active, default: true

      t.timestamps
    end
    add_index :automation_rules, :user_id, if_not_exists: true
    add_index :automation_rules, :is_active, if_not_exists: true
  end
end
