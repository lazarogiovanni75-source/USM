# frozen_string_literal: true

class CreateCompetitorPosts < ActiveRecord::Migration[7.2]
  def change
    create_table :competitor_posts do |t|
      t.references :competitor, null: false, foreign_key: true
      t.string :platform_post_id
      t.string :platform
      t.string :caption
      t.text :content
      t.bigint :likes_count, default: 0
      t.bigint :comments_count, default: 0
      t.bigint :shares_count, default: 0
      t.bigint :views_count, default: 0
      t.datetime :posted_at
      t.string :post_url
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :competitor_posts, [:competitor_id, :posted_at]
    add_index :competitor_posts, [:platform_post_id], unique: true, where: "platform_post_id IS NOT NULL"
  end
end