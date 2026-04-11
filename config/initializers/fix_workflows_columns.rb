begin
  conn = ActiveRecord::Base.connection

  unless conn.column_exists?(:workflows, :content)
    conn.execute("ALTER TABLE workflows ADD COLUMN IF NOT EXISTS content text")
  end

  unless conn.column_exists?(:workflows, :title)
    conn.execute("ALTER TABLE workflows ADD COLUMN IF NOT EXISTS title varchar")
  end

  unless conn.column_exists?(:workflows, :error_message)
    conn.execute("ALTER TABLE workflows ADD COLUMN IF NOT EXISTS error_message text")
  end
rescue => e
  Rails.logger.error "Column fix failed: #{e.message}"
end
