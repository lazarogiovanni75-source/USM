class CreateWorkflowSteps < ActiveRecord::Migration[7.2]
  def change
    create_table :workflow_steps do |t|
      t.integer :workflow_id
      t.string :step_type
      t.string :status
      t.integer :order
      t.text :output

      t.timestamps
    end
  end
end
