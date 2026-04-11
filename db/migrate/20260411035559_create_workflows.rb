class CreateWorkflows < ActiveRecord::Migration[7.2]
  def change
    create_table :workflows do |t|
      t.references :user
      t.string :workflow_type
      t.string :title
      t.text :content
      t.string :status, default: "pending"
      t.text :error_message


      t.timestamps
    end
  end
end
