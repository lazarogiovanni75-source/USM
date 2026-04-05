class AddUniqueIndexToAiMessagesId < ActiveRecord::Migration[7.2]
  def change
    add_index :ai_messages, :id, unique: true unless index_exists?(:ai_messages, :id, unique: true)
  end
end
