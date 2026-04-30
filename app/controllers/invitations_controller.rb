class InvitationsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.create_with(user_params).find_or_initialize_by(email: params[:user][:email])

    if @user.save
      send_invitation_instructions
      redirect_to new_invitation_path, notice: "An invitation email has been sent to #{@user.email}"
    else
      flash.now[:alert] = handle_password_errors(@user)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email).merge(password: SecureRandom.base58, verified: true)
  end

  def send_invitation_instructions
    signed_id = @user.generate_token_for(:password_reset)
    app_name = Rails.application.config.x.appname
    accept_url = edit_user_password_url(sid: signed_id)

    html_content = <<~HTML
      <div style="font-family:sans-serif;max-width:560px;margin:0 auto;padding:40px;">
        <h1 style="font-size:24px;font-weight:700;">You're Invited!</h1>
        <p>Hey there,</p>
        <p>Someone has invited you to join #{app_name}. Accept your invitation by clicking the link below and setting your password.</p>
        <p><a href="#{accept_url}" style="background:#2563eb;color:#fff;padding:12px 24px;text-decoration:none;border-radius:6px;display:inline-block;">Accept Invitation</a></p>
        <p style="color:#888;font-size:13px;">If you don't want to accept this invitation, you can safely ignore this email.</p>
      </div>
    HTML

    ResendEmailService.send_email(
      to: @user.email,
      subject: "[#{app_name}] You've been invited",
      html_content: html_content
    )
  end
end
