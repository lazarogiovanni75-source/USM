class UpdateCampaignsForOrchestration < ActiveRecord::Migration[7.2]
  def change
    add_column :campaigns, :strategy, :jsonb, default: {}
    add_column :campaigns, :started_at, :datetime
    add_column :campaigns, :completed_at, :datetime
    
    # First, remove the default value
    change_column_default :campaigns, :status, nil
    
    # Convert string status to integer
    execute <<-SQL
      UPDATE campaigns SET status = CASE
        WHEN status = 'draft' THEN 0
        WHEN status = 'active' THEN 3
        WHEN status = 'paused' THEN 4
        WHEN status = 'completed' THEN 5
        WHEN status = 'archived' THEN 5
        ELSE 0
      END
    SQL
    
    change_column :campaigns, :status, :integer, using: 'status::integer'
    change_column_default :campaigns, :status, 0
    
    add_index :campaigns, :status
    add_index :campaigns, :strategy, using: :gin
  end
end
