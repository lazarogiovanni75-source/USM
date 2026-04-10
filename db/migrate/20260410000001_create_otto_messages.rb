class CreateOttoMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :otto_messages do |t|
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false       # "user" or "assistant"
      t.text :content, null: false

      t.timestamps
    end

    add_index :otto_messages, [:user_id, :created_at]
  end
end
