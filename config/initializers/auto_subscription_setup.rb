# Auto-create Pro subscription for the app owner on first request
# This runs on the first web request after boot, not during asset precompile
class AutoSubscriptionSetup
  def self.call
    begin
      # Skip if not in web process or database not ready
      return if ENV['RAILS_ENV'] == 'test'
      return unless ActiveRecord::Base.connection_pool.with_connection { |c| c.active? }
      return unless ActiveRecord::Base.connection.table_exists?('users')
      return unless ActiveRecord::Base.connection.table_exists?('subscription_plans')
      return unless ActiveRecord::Base.connection.table_exists?('user_subscriptions')

      
      user_email = 'santanalazaro30@gmail.com'
      pro_plan = SubscriptionPlan.find_by(name: 'Pro')
      return Rails.logger.warn "[AutoSetup] Pro plan not found" unless pro_plan
      
      user = User.find_by(email: user_email)
      return Rails.logger.warn "[AutoSetup] User not found" unless user
      
      unless user.user_subscriptions.active.exists?
        user.user_subscriptions.create!(
          subscription_plan: pro_plan,
          status: :active,
          credits_remaining: 600,
          credits_reset_at: 1.month.from_now
        )
        Rails.logger.info "[AutoSetup] Created Pro subscription for #{user_email}"
      end
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

Rails.application.config.middleware.use AutoSubscriptionMiddleware
