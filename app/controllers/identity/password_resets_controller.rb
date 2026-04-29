class Identity::PasswordResetsController < ApplicationController
  before_action :set_user, only: %i[ edit update ]

  def new
    @user = User.new
  end

  def edit
  end

  def create
    if @user = User.find_by(email: params[:user][:email])
      send_password_reset_email
      redirect_to sign_in_path, notice: "Check your email for reset instructions"
    else
      redirect_to new_user_password_path, alert: "No account found with that email address"
    end
  end

  def update
    if @user.update(user_params)
      redirect_to sign_in_path, notice: "Your password was reset successfully. Please sign in"
    else
      flash.now[:alert] = handle_password_errors(@user)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find_by_token_for!(:password_reset, params[:sid])
  rescue StandardError
    redirect_to new_user_password_path, alert: "That password reset link is invalid"
  end

  def user_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def send_password_reset_email
    signed_id = @user.generate_token_for(:password_reset)
    app_name = Rails.application.config.x.appname
    reset_url = url_for(
      controller: "identity/password_resets",
      action: "edit",
      sid: signed_id,
      only_path: false,
      protocol: "https"
    )

    subject = "[#{app_name}] Reset your password"
    html_content = <<~HTML
      <h2>Password Reset Request</h2>
      <p>You requested a password reset for your account. Click the link below to reset your password:</p>
      <p><a href="#{reset_url}">#{reset_url}</a></p>
      <p>This link will expire in 1 hour.</p>
      <p>If you didn't request this, please ignore this email.</p>
    HTML

    SendgridEmailService.send_email(
      to: @user.email,
      subject: subject,
      html_content: html_content
    )
  end
end
