# Run on app boot to fix AI tables if they have the index bug
Rails.application.config.after_initialize do
  return unless defined?(ActiveRecord::Base)
  
  begin
    conn = ActiveRecord::Base.connection
    
    # Check if tables exist and have the bug (no primary key)
    has_bug = false
    
    if conn.table_exists?(:ai_conversations)
      indexes = conn.execute("SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'ai_conversations'")
      indexes.each do |idx|
        if idx['indexname'] == 'ai_conversations_pkey'
          Rails.logger.info "[AI Tables Fix] ai_conversations has proper primary key"
          has_bug = false
          break
        end
      end
      has_bug = true if conn.table_exists?(:ai_conversations) && !indexes.to_a.any? { |idx| idx['indexname'] == 'ai_conversations_pkey' }
    end
    
    if has_bug || !conn.table_exists?(:ai_conversations)
      Rails.logger.info "[AI Tables Fix] Detected broken AI tables, recreating..."
      
      # Drop and recreate
      conn.execute("DROP TABLE IF EXISTS ai_messages CASCADE")
      conn.execute("DROP TABLE IF EXISTS ai_conversations CASCADE")
      
      conn.execute(<<~SQL.squish)
        CREATE TABLE ai_conversations (
          id bigserial PRIMARY KEY,
          user_id bigint NOT NULL,
          title varchar(255) DEFAULT 'AI Chat',
          session_type varchar(50) DEFAULT 'general',
          metadata json,
          context jsonb DEFAULT '{}',
          memory_summary jsonb DEFAULT '{}',
          session_metadata jsonb DEFAULT '{}',
          archived boolean DEFAULT false,
          archived_at timestamp,
          created_at timestamp NOT NULL,
          updated_at timestamp NOT NULL
        )
      SQL
      
      conn.execute("CREATE INDEX idx_ai_conversations_user_id ON ai_conversations(user_id)")
      conn.execute("CREATE INDEX idx_ai_conversations_session_type ON ai_conversations(session_type)")
      
      conn.execute(<<~SQL.squish)
        CREATE TABLE ai_messages (
          id bigserial PRIMARY KEY,
          ai_conversation_id bigint NOT NULL,
          role varchar(20),
          content text,
          tokens_used integer,
          message_type varchar(20) DEFAULT 'text',
          metadata json,
          created_at timestamp NOT NULL,
          updated_at timestamp NOT NULL
        )
      SQL
      
      conn.execute("CREATE INDEX idx_ai_messages_conversation ON ai_messages(ai_conversation_id)")
      conn.execute("CREATE INDEX idx_ai_messages_role ON ai_messages(role)")
      
      # Mark migration as run
      conn.execute("DELETE FROM schema_migrations WHERE version = '20260409000003'")
      conn.execute("INSERT INTO schema_migrations (version) VALUES ('20260409000003')")
      
      Rails.logger.info "[AI Tables Fix] Tables recreated successfully!"
    end
  rescue => e
    Rails.logger.error "[AI Tables Fix] Error: #{e.message}"
  end
end
