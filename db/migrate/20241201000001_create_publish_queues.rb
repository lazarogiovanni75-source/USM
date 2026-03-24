class CreatePublishQueues < ActiveRecord::Migration[7.2]
  def change
    create_table :publish_queues, force: true do |t|
      t.references :user, null: false, foreign_key: true
      t.references :scheduled_post, null: true
      t.references :content, null: true
      t.text :platform, null: false
      t.jsonb :content_data, null: false, default: '{}'
      t.datetime :scheduled_at, null: false
      t.integer :priority, default: 5, null: false
      t.text :status, null: false, default: 'pending'
      t.datetime :published_at
      t.text :platform_post_id
      t.text :error_message
      t.integer :retry_count, default: 0
      t.datetime :next_retry_at
      t.datetime :lock_expires_at
      t.datetime :locked_at
      t.jsonb :dependency_ids, default: '[]'
      t.timestamps
    end

    add_index :publish_queues, :status
    add_index :publish_queues, :priority
    add_index :publish_queues, :scheduled_at
    add_index :publish_queues, :platform
    add_index :publish_queues, :lock_expires_at, if_not_exists: true
  end
end