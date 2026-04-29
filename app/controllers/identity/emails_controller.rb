class Identity::EmailsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to_root
    else
      flash.now[:alert] = handle_password_errors(@user)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = current_user
  end

  def user_params
    params.require(:user).permit(:email, :password_challenge).with_defaults(password_challenge: "")
  end

  def redirect_to_root
    if @user.email_previously_changed?
      resend_email_verification
      redirect_to root_path, notice: "Your email has been changed"
    else
      redirect_to root_path
    end
  end

  def resend_email_verification
    signed_id = @user.generate_token_for(:email_verification)
    app_name = Rails.application.config.x.appname
    verify_url = identity_email_verification_url(sid: signed_id)

    html_content = <<~HTML
      <div style="font-family:sans-serif;max-width:560px;margin:0 auto;padding:40px;">
        <h1 style="font-size:24px;font-weight:700;">Email Verification</h1>
        <p>Hey there,</p>
        <p>This is to confirm that <strong>#{@user.email}</strong> is the email you want to use on your account.</p>
        <p>Click the link below to verify your email address:</p>
        <p><a href="#{verify_url}" style="background:#2563eb;color:#fff;padding:12px 24px;text-decoration:none;border-radius:6px;display:inline-block;">Yes, use this email for my account</a></p>
        <p style="color:#888;font-size:13px;">If you didn't request this, you can safely ignore this email.</p>
      </div>
    HTML

    SendgridEmailService.send_email(
      to: @user.email,
      subject: "[#{app_name}] Verify your email",
      html_content: html_content
    )
  end
end
