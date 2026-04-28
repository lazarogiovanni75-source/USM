class Admin::DebugUsersController < ApplicationController
  skip_before_action :verify_authenticity_token, if: :debug_request?
  before_action :verify_debug_token, if: :debug_request?
  skip_before_action :set_user_context
  
  DEBUG_TOKEN = 'debug123'
  
  def reset_password
    email = params[:email] || 'santanalazaro30@gmail.com'
    new_password = params[:password] || 'TitoPro2024!'
    
    user = User.find_by(email: email)
    if user.nil?
      render plain: "ERROR: User not found with email: #{email}"
      return
    end
    
    # Set valid subscription_plan if current one is invalid
    if user.subscription_plan.present? && !['Starter', 'Entrepreneur', 'Pro'].include?(user.subscription_plan)
      user.subscription_plan = 'Pro'
    end
    
    user.password = new_password
    user.password_confirmation = new_password
    
    if user.save
      render plain: "SUCCESS: Password reset for #{email}\nPassword: #{new_password}\nSubscription: #{user.subscription_plan}"
    else
      render plain: "ERROR: #{user.errors.full_messages.join(', ')}\nSubscription was: #{user.subscription_plan_was}"
    end
  rescue => e
    render plain: "ERROR: #{e.message}"
  end
  
  def test_login
    email = params[:email] || 'santanalazaro30@gmail.com'
    password = params[:password] || 'TitoPro2024!'
    
    user = User.find_by(email: email)
    if user.nil?
      render plain: "ERROR: User not found with email: #{email}"
      return
    end
    
    result = user.authenticate(password)
    if result
      render plain: "AUTH SUCCESS: User authenticated!\nEmail: #{user.email}\nPassword digest exists: #{user.password_digest.present?}"
    else
      render plain: "AUTH FAILED: authenticate() returned false\nEmail: #{user.email}\nPassword digest exists: #{user.password_digest.present?}\nPossible issue: password hash in DB may be corrupted"
    end
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
