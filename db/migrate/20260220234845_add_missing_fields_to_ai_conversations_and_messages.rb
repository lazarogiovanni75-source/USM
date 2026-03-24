class AddMissingFieldsToAiConversationsAndMessages < ActiveRecord::Migration[7.2]
  def change
    # Add missing fields to ai_conversations
    unless column_exists?(:ai_conversations, :context)
      add_column :ai_conversations, :context, :jsonb, default: {}
    end
    
    unless column_exists?(:ai_conversations, :memory_summary)
      add_column :ai_conversations, :memory_summary, :jsonb, default: {}
    end
    
    unless column_exists?(:ai_conversations, :session_metadata)
      add_column :ai_conversations, :session_metadata, :jsonb, default: {}
    end
    
    unless column_exists?(:ai_conversations, :archived)
      add_column :ai_conversations, :archived, :boolean, default: false
    end
    
    unless column_exists?(:ai_conversations, :archived_at)
      add_column :ai_conversations, :archived_at, :datetime
    end
    
    # Add missing fields to ai_messages
    unless column_exists?(:ai_messages, :metadata)
      add_column :ai_messages, :metadata, :jsonb, default: {}
    end
    
    # Add indexes for better performance
    add_index :ai_conversations, :archived, if_not_exists: true
    add_index :ai_conversations, :created_at, if_not_exists: true
    add_index :ai_messages, :created_at, if_not_exists: true
  end
end
