namespace :db do
  desc "Fix ai_messages unique index"
  task fix_ai_messages_index: :environment do
    puts "Checking ai_messages table for unique index on id column..."
    
    connection = ActiveRecord::Base.connection
    
    # Check if index exists
    indexes = connection.indexes('ai_messages')
    id_index = indexes.find { |idx| idx.columns == ['id'] && idx.unique }
    
    if id_index
      puts "✅ Unique index on ai_messages.id already exists: #{id_index.name}"
    else
      puts "❌ Unique index not found. Creating it now..."
      connection.execute("CREATE UNIQUE INDEX IF NOT EXISTS index_ai_messages_on_id ON ai_messages (id);")
      puts "✅ Unique index created successfully!"
    end
    
    # Verify
    indexes = connection.indexes('ai_messages')
    id_index = indexes.find { |idx| idx.columns == ['id'] && idx.unique }
    
    if id_index
      puts "✅ Verification passed: #{id_index.name} exists and is unique"
    else
      puts "⚠️ Warning: Index may not have been created properly"
    end
  end
end
