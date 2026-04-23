class CreateAssistantConversationsFresh < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:assistant_conversations)
      create_table :assistant_conversations do |t|
        t.references :user, null: false, foreign_key: true
        t.text :messages, default: '[]'
        t.string :current_page
        t.string :title
        t.timestamps
      end
      
      add_index :assistant_conversations, :user_id
    end
  end
end
