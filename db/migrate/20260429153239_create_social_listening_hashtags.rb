# frozen_string_literal: true

class CreateSocialListeningHashtags < ActiveRecord::Migration[7.2]
  def change
    create_table :social_listening_hashtags do |t|
      t.references :user, null: false, foreign_key: true
      t.string :hashtag, null: false
      t.boolean :is_active, default: true
      t.timestamps
    end

    add_index :social_listening_hashtags, [:user_id, :hashtag], unique: true
  end
end