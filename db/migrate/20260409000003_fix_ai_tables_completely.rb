# frozen_string_literal: true

# Comprehensive fix: Drop and recreate ai_conversations and ai_messages tables
# with proper primary keys. WARNING: This will DELETE all existing data!
class FixAiTablesCompletely < ActiveRecord::Migration[7.2]
  def up
    # Drop existing tables
    drop_table :ai_messages, force: :cascade if table_exists?(:ai_messages)
    drop_table :ai_conversations, force: :cascade if table_exists?(:ai_conversations)
    
    # Create ai_conversations with proper primary key (id column auto-created)
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
    
    # Create ai_messages with proper primary key (id column auto-created)
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
    
    Rails.logger.info "Fixed: Recreated ai_conversations and ai_messages tables with proper primary keys"
  end

  def down
    # No going back - don't restore deleted data
  end
end
