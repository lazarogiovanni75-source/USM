class WaitlistController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    email = params[:email].to_s.strip.downcase

    unless ActiveRecord::Base.connection.table_exists?(:waitlist_emails)
      ActiveRecord::Base.connection.create_table :waitlist_emails do |t|
        t.string :email, null: false
        t.string :status, default: 'pending'
        t.timestamps
      end
    end

    entry = WaitlistEmail.new(email: email)

    if entry.save
      send_waitlist_confirmation(entry)
    end

    redirect_to root_path, notice: "You're on the list!"

  rescue => e
    redirect_to root_path, alert: "Something went wrong, please try again."
  end

  def send_waitlist_confirmation(entry)
    app_name = Rails.application.config.x.appname
    html_content = <<~HTML
      <div style="font-family:sans-serif;max-width:560px;margin:0 auto;padding:40px;">
        <h1 style="font-size:24px;font-weight:700;">You're on the list!</h1>
        <p>Thanks for joining the waitlist for <strong>#{app_name}</strong>.</p>
        <p>We'll be in touch soon with updates on our launch.</p>
      </div>
    HTML

    SendgridEmailService.send_email(
      to: entry.email,
      subject: "You're on the list — #{app_name}",
      html_content: html_content
    )
  rescue => e
    Rails.logger.error "Waitlist email failed: #{e.message}"
  end
end
