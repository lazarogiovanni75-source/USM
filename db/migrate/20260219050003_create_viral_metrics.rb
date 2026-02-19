class CreateViralMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :viral_metrics do |t|
      t.references :scheduled_post, null: false, foreign_key: true
      t.references :campaign, null: true, foreign_key: true
      t.references :client, null: true, foreign_key: true
      t.decimal :engagement_rate, precision: 5, scale: 2
      t.decimal :share_velocity, precision: 10, scale: 4
      t.jsonb :top_hashtags, default: []
      t.string :trend_category
      t.boolean :is_viral, default: false
      t.integer :viral_rank
      t.datetime :detected_at
      t.timestamps
    end

    add_index :viral_metrics, :is_viral
    add_index :viral_metrics, :detected_at
    add_index :viral_metrics, [:campaign_id, :detected_at]
    add_index :viral_metrics, [:client_id, :detected_at]
  end
end
