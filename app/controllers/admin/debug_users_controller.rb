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
    
    # Direct SQL to check subscriptions
    subs = ActiveRecord::Base.connection.execute(
      "SELECT id, status, credits_remaining, credits_reset_at FROM user_subscriptions WHERE user_id = #{user.id}"
    ).to_a
    
    render plain: "User: #{user.email}\n" +
      "User subscription_plan field: #{user.subscription_plan}\n" +
      "Active subscriptions found: #{subs.count}\n" +
      subs.map { |s| "  - ID: #{s['id']}, Status: #{s['status']}, Credits: #{s['credits_remaining']}, Reset: #{s['credits_reset_at']}" }.join("\n")
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
    
    conn = ActiveRecord::Base.connection
    
    # Cancel all existing subscriptions
    conn.execute("UPDATE user_subscriptions SET status = 'canceled' WHERE user_id = #{user.id}")
    
    # Add credits_remaining column if it doesn't exist
    unless conn.column_exists?(:user_subscriptions, :credits_remaining)
      conn.execute("ALTER TABLE user_subscriptions ADD COLUMN credits_remaining integer DEFAULT 0")
      conn.execute("ALTER TABLE user_subscriptions ADD COLUMN credits_reset_at timestamp")
    end
    
    # Create new subscription with direct SQL
    conn.execute("""
      INSERT INTO user_subscriptions (user_id, subscription_plan_id, status, credits_remaining, credits_reset_at, created_at, updated_at)
      VALUES (#{user.id}, #{plan.id}, 'active', #{credits}, '#{1.month.from_now.strftime('%Y-%m-%d %H:%M:%S')}', NOW(), NOW())
    """)
    
    # Update user's subscription_plan field
    user.update!(subscription_plan: plan_name)
    
    render plain: "SUCCESS!\nUser: #{user.email}\nPlan: #{plan_name}\nCredits: #{credits}\n\nRefresh the media creation page to see changes."
  rescue => e
    render plain: "ERROR: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
  end
  
  private
  
  def debug_request?
    params[:token] == DEBUG_TOKEN
  end
  
  def verify_debug_token
    head :unauthorized unless params[:token] == DEBUG_TOKEN
  end
end
