class EnsureOttoMessagesTable < ActiveRecord::Migration[7.2]
  def up
    unless table_exists?(:otto_messages)
      create_table :otto_messages do |t|
        t.references :user, null: false, foreign_key: true
        t.string :role, null: false
        t.text :content, null: false
        t.timestamps
      end

      add_index :otto_messages, [:user_id, :created_at]
    end
  end

  def down
    drop_table :otto_messages, if_exists: true
  end
end
