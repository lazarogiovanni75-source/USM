class CreateAssistantConversations < ActiveRecord::Migration[7.1]
  def change
    unless table_exists?(:assistant_conversations)
      create_table :assistant_conversations do |t|
        t.references :user, null: false, foreign_key: true
        t.text    :messages,     default: '[]'
        t.string  :current_page
        t.timestamps
      end
    end
  end
end
