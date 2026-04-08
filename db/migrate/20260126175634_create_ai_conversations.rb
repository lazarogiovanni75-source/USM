class CreateAiConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_conversations, force: true do |t|
      t.belongs_to :user, null: false
      t.string :title, default: "AI Chat"
      t.string :session_type, default: "general"
      t.json :metadata

      t.timestamps
    end
    # Explicitly add unique index on id to fix "No unique index found for id" error
    add_index :ai_conversations, :id, unique: true, if_not_exists: true
    add_index :ai_conversations, :user_id, if_not_exists: true
    add_index :ai_conversations, :session_type, if_not_exists: true
  end
end
