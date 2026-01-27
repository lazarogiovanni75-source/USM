class RegistrationsController < ApplicationController
  before_action :redirect_if_signed_in, only: [:new, :create]
  before_action :check_session_cookie_availability, only: [:new]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    
    if @user.save
      # Create a session for the newly registered user
      @session = @user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: @session.id, httponly: true }
      
      # Send email verification if email is not generated
      unless @user.email_was_generated?
        UserMailer.with(user: @user).email_verification.deliver_later
      end
      
      redirect_to root_path, notice: "Welcome! Your account has been created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def redirect_if_signed_in
    redirect_to root_path, notice: "You are already signed in" if user_signed_in?
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end