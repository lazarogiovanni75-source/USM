# Auto-create Pro subscription for the app owner
Rails.application.config.after_initialize do
  ActiveSupport.on_load(:active_record) do
    # Skip if database not ready or running migrations
    next unless ActiveRecord::Base.connection.table_exists?('users')
    next unless ActiveRecord::Base.connection.table_exists?('subscription_plans')
    next unless ActiveRecord::Base.connection.table_exists?('user_subscriptions')
    
    begin
      user_email = 'santanalazaro30@gmail.com'
      pro_plan = SubscriptionPlan.find_by(name: 'Pro')
      
      if pro_plan.nil?
        Rails.logger.warn "[AutoSetup] Pro subscription plan not found. Please create it in the admin panel."
        next
      end
      
      user = User.find_by(email: user_email)
      
      if user.nil?
        Rails.logger.warn "[AutoSetup] User #{user_email} not found."
        next
      end
      
      # Check if user already has an active subscription
      existing_sub = user.user_subscriptions.active.first
      
      if existing_sub.nil?
        user.user_subscriptions.create!(
          subscription_plan: pro_plan,
          status: :active,
          credits_remaining: 600,
          credits_reset_at: 1.month.from_now
        )
        Rails.logger.info "[AutoSetup] Created Pro subscription for #{user_email} with 600 credits."
      else
        Rails.logger.info "[AutoSetup] User #{user_email} already has active subscription: #{existing_sub.subscription_plan.name}"
      end
    rescue => e
      Rails.logger.warn "[AutoSetup] Skipped: #{e.message}"
    end
  end
end
