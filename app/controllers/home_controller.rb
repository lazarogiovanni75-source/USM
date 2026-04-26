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

  # Emergency password reset - GET shows form
  def reset_password
    render json: { message: 'POST to this URL with email and password params' }
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
