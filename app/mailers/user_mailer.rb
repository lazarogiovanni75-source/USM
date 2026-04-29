class UserMailer < ApplicationMailer
  def password_reset
    @user = params[:user]
    @signed_id = @user.generate_token_for(:password_reset)

    app_name = Rails.application.config.x.appname.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    mail to: @user.email, subject: "[#{app_name}] Reset your password"
  end

  def email_verification
    @user = params[:user]
    @signed_id = @user.generate_token_for(:email_verification)

    app_name = Rails.application.config.x.appname.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    mail to: @user.email, subject: "[#{app_name}] Verify your email"
  end

  def invitation_instructions
    @user = params[:user]
    @signed_id = @user.generate_token_for(:password_reset)

    app_name = Rails.application.config.x.appname.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    mail to: @user.email, subject: "[#{app_name}] Invitation instructions"
  end
end
