# frozen_string_literal: true

class CreateSocialListeningKeywords < ActiveRecord::Migration[7.2]
  def change
    create_table :social_listening_keywords do |t|
      t.references :user, null: false, foreign_key: true
      t.string :keyword, null: false
      t.boolean :is_active, default: true
      t.timestamps
    end

    add_index :social_listening_keywords, [:user_id, :keyword], unique: true
  end
end