class CreateCampaignTasks < ActiveRecord::Migration[7.2]
  def change
    create_table :campaign_tasks do |t|
      t.references :campaign, null: false, foreign_key: true
      t.string :tool_name
      t.jsonb :parameters, default: {}
      t.integer :status, default: 0, null: false
      t.text :result
      t.text :error_message
      t.integer :priority, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :campaign_tasks, :status
  end
end
