# Auto-create Pro subscription for the app owner and investor on first request
# Also resets password to a known value on every boot
class AutoSubscriptionSetup
  def self.setup_user(user_email, password = nil)
    user = User.find_by(email: user_email)
    return Rails.logger.warn "[AutoSetup] User not found: #{user_email}" unless user
    
    # Reset password on every boot to ensure access
    if password
      user.password = password
      user.password_confirmation = password
      if user.save
        Rails.logger.info "[AutoSetup] Password reset for #{user_email}"
      else
        Rails.logger.warn "[AutoSetup] Password reset failed for #{user_email}: #{user.errors.full_messages.join(', ')}"
      end
    end
    
    pro_plan = SubscriptionPlan.find_by(name: 'Pro')
    return Rails.logger.warn "[AutoSetup] Pro plan not found" unless pro_plan
    
    unless user.user_subscriptions.active.exists?
      user.user_subscriptions.create!(
        subscription_plan: pro_plan,
        status: :active,
        credits_remaining: 600,
        credits_reset_at: 1.month.from_now
      )
      Rails.logger.info "[AutoSetup] Created Pro subscription for #{user_email}"
    end
  end

  def self.call
    begin
      # Skip if not in web process or database not ready
      return if ENV['RAILS_ENV'] == 'test'
      return unless ActiveRecord::Base.connection_pool.with_connection { |c| c.active? }
      return unless ActiveRecord::Base.connection.table_exists?('users')
      return unless ActiveRecord::Base.connection.table_exists?('subscription_plans')
      return unless ActiveRecord::Base.connection.table_exists?('user_subscriptions')
      
      # Setup app owner
      setup_user('santanalazaro30@gmail.com', 'TitoPro2024!')
      
      # Setup investor
      investor_email = 'investor@usm.app'
      investor = User.find_by(email: investor_email)
      
      # Create investor user if not exists
      unless investor
        investor = User.create!(
          email: investor_email,
          password: 'InvestorPro2024!',
          password_confirmation: 'InvestorPro2024!',
          name: 'USM Investor'
        )
        Rails.logger.info "[AutoSetup] Created investor user: #{investor_email}"
      end
      
      setup_user(investor_email, 'InvestorPro2024!')
    rescue => e
      Rails.logger.warn "[AutoSetup] Skipped: #{e.message}"
    end
  end
end

# Schedule for first request using Rack middleware
class AutoSubscriptionMiddleware
  @@already_ran = false
  
  def initialize(app)
    @app = app
  end
  
  def call(env)
    unless @@already_ran
      @@already_ran = true
      AutoSubscriptionSetup.call
    end
    @app.call(env)
  end
end

# Auto-subscription setup temporarily disabled to fix deployment
# Use /reset-my-password endpoint instead
# Rails.application.config.middleware.use AutoSubscriptionMiddleware
