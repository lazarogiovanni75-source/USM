class CreateAssistantConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :assistant_conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.text :messages, default: '[]'
      t.string :current_page
      t.timestamps
    end
  end
end
