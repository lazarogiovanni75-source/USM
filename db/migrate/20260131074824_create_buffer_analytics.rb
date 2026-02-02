class CreateBufferAnalytics < ActiveRecord::Migration[7.2]
  def change
    create_table :buffer_analytics do |t|
      t.references :scheduled_post
      t.string :buffer_update_id
      t.integer :clicks
      t.integer :impressions
      t.integer :engagement
      t.integer :reach
      t.integer :shares
      t.integer :likes
      t.integer :comments
      t.datetime :posted_at
      t.datetime :synced_at


      t.timestamps
    end
  end
end
