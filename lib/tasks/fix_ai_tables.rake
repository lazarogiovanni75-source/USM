namespace :ai do
  desc "Force fix ai_conversations and ai_messages tables"
  task fix_tables: :environment do
    conn = ActiveRecord::Base.connection
    
    puts "=== Fixing AI Tables ==="
    
    # Drop existing tables
    puts "Dropping existing tables..."
    conn.execute("DROP TABLE IF EXISTS ai_messages CASCADE")
    conn.execute("DROP TABLE IF EXISTS ai_conversations CASCADE")
    
    # Create ai_conversations fresh
    puts "Creating ai_conversations..."
    conn.execute(<<~SQL)
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
    conn.execute("CREATE INDEX idx_ai_conversations_archived ON ai_conversations(archived)")
    
    # Create ai_messages fresh
    puts "Creating ai_messages..."
    conn.execute(<<~SQL)
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
    conn.execute("ALTER TABLE ai_messages ADD CONSTRAINT fk_ai_messages_conversation FOREIGN KEY (ai_conversation_id) REFERENCES ai_conversations(id) ON DELETE CASCADE")
    
    # Record this migration
    conn.execute("DELETE FROM schema_migrations WHERE version = '20260409000003'")
    conn.execute("INSERT INTO schema_migrations (version) VALUES ('20260409000003')")
    
    puts "=== AI Tables Fixed! ==="
    puts "Tables recreated with proper primary keys (bigserial)"
  end
end
