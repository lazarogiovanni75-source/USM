begin
  conn = ActiveRecord::Base.connection
  unless conn.column_exists?(:workflows, :result)
    conn.execute("ALTER TABLE workflows ADD COLUMN result text")
  end
rescue => e
  Rails.logger.error "Add workflow result column failed: #{e.message}"
end
