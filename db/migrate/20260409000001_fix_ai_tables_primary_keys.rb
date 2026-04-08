# frozen_string_literal: true

# Migration to ensure ai_conversations and ai_messages tables have proper primary keys
# This addresses "No unique index found for id" errors
# The core issue: Rails insert_all/upsert_all requires explicit unique index on id
class FixAiTablesPrimaryKeys < ActiveRecord::Migration[7.2]
  def up
    # Create unique index on ai_conversations.id if it doesn't exist
    unless index_exists?(:ai_conversations, :id, unique: true)
      begin
        execute "CREATE UNIQUE INDEX IF NOT EXISTS index_ai_conversations_on_id ON ai_conversations (id);"
        Rails.logger.info "Created unique index on ai_conversations.id"
      rescue => e
        Rails.logger.error "Failed to create index on ai_conversations: #{e.message}"
      end
    end
    
    # Create unique index on ai_messages.id if it doesn't exist
    unless index_exists?(:ai_messages, :id, unique: true)
      begin
        execute "CREATE UNIQUE INDEX IF NOT EXISTS index_ai_messages_on_id ON ai_messages (id);"
        Rails.logger.info "Created unique index on ai_messages.id"
      rescue => e
        Rails.logger.error "Failed to create index on ai_messages: #{e.message}"
      end
    end
  end

  def down
    # Don't remove indexes on down - they're essential
  end
end
