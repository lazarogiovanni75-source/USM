# frozen_string_literal: true

# NEW migration to ensure ai_conversations and ai_messages tables have proper primary keys
# This is a fresh migration that will definitely run
class EnsurePrimaryKeys < ActiveRecord::Migration[7.2]
  def up
    # Force create unique indexes on id columns for both tables
    # This fixes "No unique index found for id" errors
    
    execute "CREATE UNIQUE INDEX IF NOT EXISTS idx_ai_conv_id ON ai_conversations (id);" rescue nil
    execute "CREATE UNIQUE INDEX IF NOT EXISTS idx_ai_msg_id ON ai_messages (id);" rescue nil
    
    Rails.logger.info "EnsurePrimaryKeys: Attempted to create unique indexes"
  end

  def down
    # No-op
  end
end
