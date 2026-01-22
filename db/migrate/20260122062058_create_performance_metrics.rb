class CreatePerformanceMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :performance_metrics do |t|
      t.references :scheduled_post
      t.integer :impressions, default: 0
      t.integer :likes, default: 0
      t.integer :comments, default: 0
      t.integer :shares, default: 0
      t.decimal :engagement_rate, default: 0.0
      t.integer :reach, default: 0


      t.timestamps
    end
  end
end
