# frozen_string_literal: true

class CreateSocialListeningAlerts < ActiveRecord::Migration[7.2]
  def change
    create_table :social_listening_alerts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :platform
      t.string :keyword
      t.string :alert_type, null: false
      t.text :content
      t.string :author_handle
      t.string :author_name
      t.bigint :author_followers, default: 0
      t.string :mention_url
      t.string :sentiment, default: 'neutral'
      t.float :sentiment_score, default: 0.0
      t.bigint :likes_count, default: 0
      t.bigint :comments_count, default: 0
      t.boolean :is_verified, default: false
      t.datetime :mentioned_at
      t.datetime :read_at
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :social_listening_alerts, [:user_id, :read_at]
    add_index :social_listening_alerts, [:platform]
    add_index :social_listening_alerts, [:sentiment]
    add_index :social_listening_alerts, [:alert_type]
  end
end