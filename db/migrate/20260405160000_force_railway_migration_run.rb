class ForceRailwayMigrationRun < ActiveRecord::Migration[7.2]
  def up
    # Force-ensure the unique index exists on ai_messages.id
    unless index_exists?(:ai_messages, :id, unique: true)
      add_index :ai_messages, :id, unique: true
      puts "✅ Added unique index to ai_messages.id"
    else
      puts "✅ Unique index on ai_messages.id already exists"
    end
  end

  def down
    # Don't remove the index on rollback - it's a primary key requirement
  end
end
