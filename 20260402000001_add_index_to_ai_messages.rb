class AddIndexToAiMessages < ActiveRecord::Migration[7.2]
  def change
    unless index_exists?(:ai_messages, :id, unique: true)
      add_index :ai_messages, :id, unique: true
    end
  end
end
