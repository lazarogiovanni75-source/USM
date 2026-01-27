class CreateContentSuggestions < ActiveRecord::Migration[7.2]
  def change
    create_table :content_suggestions, force: true do |t|
      t.belongs_to :user, null: false
      t.string :content_type
      t.text :topic
      t.text :suggestion
      t.decimal :confidence
      t.string :status, default: "pending"

      t.timestamps
    end
    add_index :content_suggestions, :user_id, if_not_exists: true
    add_index :content_suggestions, :status, if_not_exists: true
  end
end
