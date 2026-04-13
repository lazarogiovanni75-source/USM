# Ensures otto_messages table exists even if migration was skipped

Rails.application.config.after_initialize do
  begin
    unless ActiveRecord::Base.connection.table_exists?(:otto_messages)
      ActiveRecord::Base.connection.create_table :otto_messages do |t|
        t.bigint :user_id, null: false
        t.string :role, null: false
        t.text :content
        t.string :message_type, default: "text"
        t.jsonb :metadata, default: {}
        t.timestamps
      end

      ActiveRecord::Base.connection.add_index :otto_messages, :user_id

      Rails.logger.info "Created otto_messages table via initializer"
    end
  rescue => e
    Rails.logger.error "Failed to ensure otto_messages table: #{e.message}"
  end
end
