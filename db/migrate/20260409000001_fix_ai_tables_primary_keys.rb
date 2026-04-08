# frozen_string_literal: true

# Fix migration to ensure ai_conversations and ai_messages tables have proper primary keys
# This addresses "No unique index found for id" errors
class FixAiTablesPrimaryKeys < ActiveRecord::Migration[7.2]
  def up
    # Ensure ai_conversations has primary key
    unless index_exists?(:ai_conversations, :id, unique: true)
      execute "ALTER TABLE ai_conversations ADD PRIMARY KEY (id)" rescue nil
    end
    
    # Ensure ai_messages has primary key
    unless index_exists?(:ai_messages, :id, unique: true)
      execute "ALTER TABLE ai_messages ADD PRIMARY KEY (id)" rescue nil
    end
  end

  def down
    # No-op - don't remove primary keys
  end
end
