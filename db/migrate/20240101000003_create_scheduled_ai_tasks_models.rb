class CreateScheduledAiTasksModels < ActiveRecord::Migration[7.2]
  def change
    create_table :scheduled_ai_tasks do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :task_type, null: false
      t.string :schedule_type, null: false
      t.string :status, default: 'active'
      t.datetime :next_run_at
      t.jsonb :config, default: {}
      t.timestamps
    end
    
    create_table :task_executions do |t|
      t.references :scheduled_ai_task, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, default: 'executed'
      t.jsonb :execution_data, default: {}
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end
    
    create_table :ai_task_results do |t|
      t.references :user, null: false, foreign_key: true
      t.string :task_type, null: false
      t.text :summary
      t.jsonb :result_data, default: {}
      t.timestamps
    end
    
    # Add indexes for performance
    add_index :scheduled_ai_tasks, :status
    add_index :scheduled_ai_tasks, :task_type
    add_index :scheduled_ai_tasks, :next_run_at
    
    add_index :task_executions, :status
    add_index :task_executions, :created_at
    
    add_index :ai_task_results, :task_type
    add_index :ai_task_results, :created_at
  end
end