class CreateOttoMessages < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:otto_messages)

    create_table :otto_messages do |t|
      t.bigint :user_id, null: false
      t.string :role, null: false
      t.text :content
      t.string :message_type, default: "text"
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :otto_messages, :user_id
  end
end
