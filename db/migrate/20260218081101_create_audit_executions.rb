class CreateAuditExecutions < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_executions do |t|
      t.references :user
      t.string :tool_name
      t.text :parameters
      t.string :status
      t.boolean :approved
      t.datetime :executed_at
      t.string :session_id

      t.index :tool_name
      t.index :status
      t.index :executed_at
      t.index :session_id

      t.timestamps
    end
  end
end
