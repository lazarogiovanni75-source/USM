class CreateAiMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_messages, force: true do |t|
      t.belongs_to :ai_conversation, null: false
      t.string :role
      t.text :content
      t.integer :tokens_used

      t.timestamps
    end
    add_index :ai_messages, :ai_conversation_id, if_not_exists: true
    add_index :ai_messages, :role, if_not_exists: true
  end
end
