# frozen_string_literal: true

# Fresh migration to recreate AI tables with proper primary key indexes
# This fixes "No unique index found for id" ArgumentError
class RecreateAiTables < ActiveRecord::Migration[7.2]
  def up
    # Drop existing tables if they exist
    drop_table :ai_messages, if_exists: true
    drop_table :ai_conversations, if_exists: true

    # Create ai_conversations with proper structure
    create_table :ai_conversations, force: true do |t|
      t.bigint :user_id, null: false
      t.string :title, default: "AI Chat"
      t.string :session_type, default: "general"
      t.json :metadata, default: {}
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.jsonb :context, default: {}
      t.jsonb :memory_summary, default: {}
      t.jsonb :session_metadata, default: {}
      t.boolean :archived, default: false
      t.datetime :archived_at
    end

    # Add indexes including UNIQUE index on id (the key fix)
    add_index :ai_conversations, :id, unique: true
    add_index :ai_conversations, :user_id
    add_index :ai_conversations, :session_type
    add_index :ai_conversations, :created_at
    add_index :ai_conversations, :archived

    # Create ai_messages with proper structure
    create_table :ai_messages, force: true do |t|
      t.bigint :ai_conversation_id, null: false
      t.string :role
      t.text :content
      t.integer :tokens_used
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.string :message_type, default: "text"
      t.jsonb :metadata, default: {}
    end

    # Add indexes including UNIQUE index on id
    add_index :ai_messages, :id, unique: true
    add_index :ai_messages, :ai_conversation_id
    add_index :ai_messages, :role
    add_index :ai_messages, :created_at
  end

  def down
    drop_table :ai_messages, if_exists: true
    drop_table :ai_conversations, if_exists: true
  end
end
