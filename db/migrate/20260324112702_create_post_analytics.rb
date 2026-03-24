class CreatePostAnalytics < ActiveRecord::Migration[7.2]
  def change
    # Only create table if it doesn't exist (make migration idempotent)
    unless table_exists?(:post_analytics)
      create_table :post_analytics do |t|
        t.references :scheduled_post, null: false, foreign_key: true
        t.string :postforme_post_id
        t.integer :likes, default: 0
        t.integer :comments, default: 0
        t.integer :shares, default: 0
        t.integer :saves, default: 0
        t.integer :clicks, default: 0
        t.integer :impressions, default: 0
        t.integer :reach, default: 0
        t.integer :views, default: 0
        t.decimal :engagement_rate, precision: 5, scale: 2, default: 0
        t.json :raw_data, default: {}
        t.datetime :fetched_at
        t.datetime :posted_at

        t.timestamps
      end

      # Only add indexes if they don't exist
      add_index :post_analytics, :postforme_post_id unless index_exists?(:post_analytics, :postforme_post_id)
      add_index :post_analytics, :fetched_at unless index_exists?(:post_analytics, :fetched_at)
      unless index_exists?(:post_analytics, :scheduled_post_id)
        add_index :post_analytics, :scheduled_post_id, unique: true
      end
    end
  end
end
