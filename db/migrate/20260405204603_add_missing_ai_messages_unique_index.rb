class AddMissingAiMessagesUniqueIndex < ActiveRecord::Migration[7.2]
  def change
    # Use raw SQL to ensure the unique index exists - bypasses Rails migration issues
    unless index_exists?(:ai_messages, :id, unique: true)
      add_index :ai_messages, :id, unique: true
    end
  end
end
