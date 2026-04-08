class AddUniqueIndexToAiMessagesId < ActiveRecord::Migration[7.2]
  def change
    unless index_exists?(:ai_messages, :id, unique: true)
      add_index :ai_messages, :id, unique: true, name: :index_ai_messages_on_id
    end
  end
end
