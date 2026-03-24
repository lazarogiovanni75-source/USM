class CreateWorkflows < ActiveRecord::Migration[7.2]
  def change
    create_table :workflows do |t|
      t.integer :user_id
      t.string :workflow_type
      t.string :status
      t.text :params

      t.timestamps
    end
  end
end
