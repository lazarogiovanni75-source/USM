# frozen_string_literal: true

# Migration to create post_metrics table
class CreatePostMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :post_metrics do |t|
      t.references :post, polymorphic: true, null: false
      t.string :platform
      t.bigint :social_account_id
      t.string :platform_post_id
      t.integer :impressions, default: 0
      t.integer :likes, default: 0
      t.integer :comments, default: 0
      t.integer :shares, default: 0
      t.integer :saves, default: 0
      t.integer :clicks, default: 0
      t.float :engagement_rate, default: 0.0
      t.float :click_through_rate, default: 0.0
      t.jsonb :raw_metrics, default: {}
      t.datetime :collected_at
      t.timestamps
    end
    
    add_index :post_metrics, [:post_type, :post_id]
    add_index :post_metrics, :social_account_id
    add_index :post_metrics, :platform_post_id
    add_index :post_metrics, :collected_at
  end
end
