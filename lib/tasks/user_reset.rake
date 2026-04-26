namespace :users do
  desc "Reset password for user by email"
  task :reset_password, [:email, :password] => :environment do |_t, args|
    email = args[:email] || 'santanalazaro30@gmail.com'
    password = args[:password] || 'TitoPro2024!'

    user = User.find_by(email: email)

    if user.nil?
      puts "ERROR: User not found with email: #{email}"
      exit 1
    end

    user.password = password
    user.password_confirmation = password

    if user.save
      puts "SUCCESS: Password reset for #{email}"
      puts "New password: #{password}"
    else
      puts "ERROR: Failed to save user"
      puts user.errors.full_messages.join("\n")
      exit 1
    end
  end

  desc "Reset password for santanalazaro30@gmail.com (default)"
  task :reset_tito_password => :environment do
    Rake::Task['users:reset_password'].invoke('santanalazaro30@gmail.com', 'TitoPro2024!')
  end
end
