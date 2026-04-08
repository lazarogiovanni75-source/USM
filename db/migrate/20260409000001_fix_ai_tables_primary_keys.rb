# frozen_string_literal: true

# Fix migration to ensure ai_conversations and ai_messages tables have proper primary keys
# This addresses "No unique index found for id" errors
class FixAiTablesPrimaryKeys < ActiveRecord::Migration[7.2]
  def up
    # Check if id column exists and has proper serial/bigint type
    if column_exists?(:ai_conversations, :id)
      # Ensure it's the primary key
      begin
        execute "ALTER TABLE ai_conversations ALTER COLUMN id SET DATA TYPE bigint" rescue nil
        execute "ALTER TABLE ai_conversations ADD CONSTRAINT ai_conversations_pkey PRIMARY KEY (id)" rescue nil
      rescue => e
        Rails.logger.info "ai_conversations primary key: #{e.message}"
      end
    end
    
    if column_exists?(:ai_messages, :id)
      begin
        execute "ALTER TABLE ai_messages ALTER COLUMN id SET DATA TYPE bigint" rescue nil
        execute "ALTER TABLE ai_messages ADD CONSTRAINT ai_messages_pkey PRIMARY KEY (id)" rescue nil
      rescue => e
        Rails.logger.info "ai_messages primary key: #{e.message}"
      end
    end
  end

  def down
    # No-op
  end
end
