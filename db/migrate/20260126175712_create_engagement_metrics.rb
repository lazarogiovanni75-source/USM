class CreateEngagementMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :engagement_metrics, force: true do |t|
      t.belongs_to :user, null: false
      t.belongs_to :content
      t.string :metric_type
      t.decimal :metric_value
      t.date :date

      t.timestamps
    end
    add_index :engagement_metrics, :user_id, if_not_exists: true
    add_index :engagement_metrics, :content_id, if_not_exists: true
    add_index :engagement_metrics, :metric_type, if_not_exists: true
  end
end
