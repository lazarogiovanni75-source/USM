class CreateScheduledTasks < ActiveRecord::Migration[7.2]
  def change
    create_table :scheduled_tasks, force: true do |t|
      t.belongs_to :user, null: false
      t.string :task_type
      t.json :payload
      t.datetime :scheduled_at
      t.datetime :executed_at
      t.string :status, default: "pending"

      t.timestamps
    end
    add_index :scheduled_tasks, :user_id, if_not_exists: true
    add_index :scheduled_tasks, :status, if_not_exists: true
  end
end
