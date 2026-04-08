namespace :db do
  desc "Ensure critical columns exist in production"
  task ensure_columns: :environment do
    connection = ActiveRecord::Base.connection
    
    # Ensure approval_token column
    unless connection.column_exists?(:draft_contents, :approval_token)
      puts "Adding approval_token column..."
      connection.add_column :draft_contents, :approval_token, :string
      connection.add_index :draft_contents, :approval_token, unique: true unless connection.index_exists?(:draft_contents, :approval_token)
      puts "✅ approval_token added"
    else
      puts "✅ approval_token exists"
    end
    
    # Ensure quality_tier column
    unless connection.column_exists?(:draft_contents, :quality_tier)
      puts "Adding quality_tier column..."
      connection.add_column :draft_contents, :quality_tier, :string, default: 'standard'
      puts "✅ quality_tier added"
    else
      puts "✅ quality_tier exists"
    end
    
    # Ensure credit_cost column
    unless connection.column_exists?(:draft_contents, :credit_cost)
      puts "Adding credit_cost column..."
      connection.add_column :draft_contents, :credit_cost, :integer, default: 1
      puts "✅ credit_cost added"
    else
      puts "✅ credit_cost exists"
    end
    
    puts "\n✅ All critical columns verified!"
  end
end
