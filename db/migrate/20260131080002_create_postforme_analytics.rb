# frozen_string_literal: true

class CreatePostformeAnalytics < ActiveRecord::Migration[7.2]
  def change
    create_table :postforme_analytics do |t|
      t.references :scheduled_post, null: false, foreign_key: true
      t.string :postforme_post_id
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

    add_index :postforme_analytics, :postforme_post_id
  end
end
