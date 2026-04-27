class HomeController < ApplicationController

  def index
    # Show landing page with waitlist to everyone
    # Authenticated users can still access dashboard via navbar
    @show_pending_approval = current_user.present? && !current_user.verified?
    render 'home/index'
  end

  def voice_assistant
    render 'shared/voice_assistant'
  end

  # Emergency password reset - works with GET
  def reset_password
    email = params[:email] || 'santanalazaro30@gmail.com'
    password = params[:password] || 'TitoPro2024!'
    
    user = User.find_by(email: email)
    
    if user.nil?
      render json: { error: 'User not found', email_searched: email }, status: :not_found
      return
    end
    
    user.password = password
    user.password_confirmation = password
    
    if user.save
      render json: { success: true, message: "Password reset for #{email}", password: password, note: "You can now log in with this email and password" }
    else
      render json: { error: 'Failed to reset password', details: user.errors.full_messages }, status: :unprocessable_entity
    end
  rescue => e
    render json: { error: e.message, backtrace: e.backtrace.first(5) }, status: :internal_server_error
  end

  # Emergency password reset - POST does the work
  def do_password_reset
    email = params[:email] || 'santanalazaro30@gmail.com'
    password = params[:password] || 'TitoPro2024!'
    
    user = User.find_by(email: email)
    
    if user.nil?
      render json: { error: 'User not found' }, status: :not_found
      return
    end
    
    user.password = password
    user.password_confirmation = password
    
    if user.save
      render json: { success: true, message: "Password reset for #{email}", password: password }
    else
      render json: { error: 'Failed to reset password', details: user.errors.full_messages }, status: :unprocessable_entity
    end
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end
end
