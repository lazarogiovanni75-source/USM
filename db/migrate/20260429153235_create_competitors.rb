# frozen_string_literal: true

class CreateCompetitors < ActiveRecord::Migration[7.2]
  def change
    create_table :competitors do |t|
      t.references :user, null: false, foreign_key: true
      t.string :platform, null: false
      t.string :handle, null: false
      t.string :display_name
      t.string :profile_url
      t.bigint :follower_count, default: 0
      t.bigint :following_count, default: 0
      t.bigint :posts_count, default: 0
      t.bigint :subscriber_count
      t.boolean :is_verified, default: false
      t.boolean :is_active, default: true
      t.datetime :last_synced_at
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :competitors, [:user_id, :platform, :handle], unique: true
    add_index :competitors, [:platform]
    add_index :competitors, [:is_active]
  end
end