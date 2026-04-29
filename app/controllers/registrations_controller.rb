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
        send_verification_email(@user)
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
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :phone, :business_name)
  end

  def send_verification_email(user)
    signed_id = user.generate_token_for(:email_verification)
    app_name = Rails.application.config.x.appname
    verify_url = identity_email_verification_url(sid: signed_id)

    html_content = <<~HTML
      <div style="font-family:sans-serif;max-width:560px;margin:0 auto;padding:40px;">
        <h1 style="font-size:24px;font-weight:700;">Email Verification</h1>
        <p>Hey there,</p>
        <p>This is to confirm that <strong>#{user.email}</strong> is the email you want to use on your account.</p>
        <p>Click the link below to verify your email address:</p>
        <p><a href="#{verify_url}" style="background:#2563eb;color:#fff;padding:12px 24px;text-decoration:none;border-radius:6px;display:inline-block;">Yes, use this email for my account</a></p>
        <p style="color:#888;font-size:13px;">If you didn't request this, you can safely ignore this email.</p>
      </div>
    HTML

    SendgridEmailService.send_email(
      to: user.email,
      subject: "[#{app_name}] Verify your email",
      html_content: html_content
    )
  end
end