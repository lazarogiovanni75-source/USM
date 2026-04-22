class AddTitleToAssistantConversations < ActiveRecord::Migration[7.2]
  def change
    add_column :assistant_conversations, :title, :string
  end
end
