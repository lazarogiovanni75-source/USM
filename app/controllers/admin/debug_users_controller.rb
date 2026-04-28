class Admin::DebugUsersController < ApplicationController
  skip_before_action :verify_authenticity_token, if: :debug_request?
  before_action :verify_debug_token, if: :debug_request?
  skip_before_action :set_user_context
  
  DEBUG_TOKEN = 'debug123'
  
  def check_subscription
    email = params[:email] || 'santanalazaro30@gmail.com'
    user = User.find_by(email: email)
    
    if user.nil?
      render plain: "ERROR: User not found"
      return
    end
    
    subscriptions = user.user_subscriptions.active
    credits_info = user.user_subscriptions.active.first&.credit_status
    
    render plain: "User: #{user.email}\n" +
      "Subscription count: #{subscriptions.count}\n" +
      "Plan: #{user.subscription_plan}\n" +
      "Credits remaining: #{credits_info&.dig(:remaining) || 'N/A'}\n" +
      "Credits total: #{credits_info&.dig(:total) || 'N/A'}"
  end
  
  def fix_subscription
    email = params[:email] || 'santanalazaro30@gmail.com'
    plan_name = params[:plan] || 'Pro'
    credits = params[:credits].to_i > 0 ? params[:credits].to_i : 600
    
    user = User.find_by(email: email)
    
    if user.nil?
      render plain: "ERROR: User not found"
      return
    end
    
    plan = SubscriptionPlan.find_by(name: plan_name)
    if plan.nil?
      render plain: "ERROR: Plan '#{plan_name}' not found. Available: Starter, Entrepreneur, Pro"
      return
    end
    
    # Deactivate old subscriptions
    user.user_subscriptions.update_all(status: :cancelled)
    
    # Create new subscription
    subscription = user.user_subscriptions.create!(
      subscription_plan: plan,
      status: :active,
      credits_remaining: credits,
      credits_reset_at: 1.month.from_now
    )
    
    # Update user's subscription_plan field too
    user.update!(subscription_plan: plan_name)
    
    render plain: "SUCCESS!\nUser: #{user.email}\nPlan: #{plan_name}\nCredits: #{credits}\nSubscription ID: #{subscription.id}"
  rescue => e
    render plain: "ERROR: #{e.message}"
  end
  
  private
  
  def debug_request?
    params[:token] == DEBUG_TOKEN
  end
  
  def verify_debug_token
    head :unauthorized unless params[:token] == DEBUG_TOKEN
  end
end
