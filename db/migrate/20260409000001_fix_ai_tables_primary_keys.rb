# frozen_string_literal: true

# Aggressive fix migration to ensure ai_conversations and ai_messages tables have proper primary keys
# This addresses "No unique index found for id" errors by recreating tables if needed
class FixAiTablesPrimaryKeys < ActiveRecord::Migration[7.2]
  def up
    # Check if ai_conversations exists and has proper primary key
    if table_exists?(:ai_conversations)
      begin
        # Try to ensure primary key exists
        unless index_exists?(:ai_conversations, :id, unique: true)
          # Drop and recreate the table with proper structure
          drop_table :ai_conversations, force: :cascade
          create_table :ai_conversations do |t|
            t.bigint :user_id, null: false
            t.string :title, default: "AI Chat"
            t.string :session_type, default: "general"
            t.json :metadata
            t.jsonb :context, default: {}
            t.jsonb :memory_summary, default: {}
            t.jsonb :session_metadata, default: {}
            t.boolean :archived, default: false
            t.datetime :archived_at
            t.timestamps
          end
          add_index :ai_conversations, :user_id
          add_index :ai_conversations, :session_type
          add_index :ai_conversations, :archived
        end
      rescue => e
        Rails.logger.error "ai_conversations fix error: #{e.message}"
      end
    else
      # Table doesn't exist, create it
      create_table :ai_conversations do |t|
        t.bigint :user_id, null: false
        t.string :title, default: "AI Chat"
        t.string :session_type, default: "general"
        t.json :metadata
        t.jsonb :context, default: {}
        t.jsonb :memory_summary, default: {}
        t.jsonb :session_metadata, default: {}
        t.boolean :archived, default: false
        t.datetime :archived_at
        t.timestamps
      end
      add_index :ai_conversations, :user_id
      add_index :ai_conversations, :session_type
      add_index :ai_conversations, :archived
    end
    
    # Same for ai_messages
    if table_exists?(:ai_messages)
      begin
        unless index_exists?(:ai_messages, :id, unique: true)
          drop_table :ai_messages, force: :cascade
          create_table :ai_messages do |t|
            t.bigint :ai_conversation_id, null: false
            t.string :role
            t.text :content
            t.integer :tokens_used
            t.string :message_type
            t.json :metadata
            t.timestamps
          end
          add_index :ai_messages, :ai_conversation_id
          add_index :ai_messages, :role
        end
      rescue => e
        Rails.logger.error "ai_messages fix error: #{e.message}"
      end
    else
      create_table :ai_messages do |t|
        t.bigint :ai_conversation_id, null: false
        t.string :role
        t.text :content
        t.integer :tokens_used
        t.string :message_type
        t.json :metadata
        t.timestamps
      end
      add_index :ai_messages, :ai_conversation_id
      add_index :ai_messages, :role
    end
  end

  def down
    # No-op - we don't want to lose data
  end
end
