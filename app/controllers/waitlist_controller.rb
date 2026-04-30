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
      begin
        html_content = <<~HTML
          <!DOCTYPE html><html><body style="background:#080808;color:#f8f6f1;font-family:sans-serif;padding:40px;">
          <div style="max-width:560px;margin:0 auto;">
            <h1 style="font-size:32px;font-weight:300;">You're <span style="color:#c9a84c;">on the list.</span></h1>
            <p style="color:#9a9a9a;line-height:1.7;">Thank you for joining the waitlist. You'll be among the first to get access when we launch.</p>
            <a href="https://ultimatesocialmedia01.com" style="display:inline-block;margin-top:32px;padding:14px 32px;background:#c9a84c;color:#080808;font-weight:600;font-size:13px;letter-spacing:0.1em;text-decoration:none;">Learn More</a>
          </div></body></html>
        HTML

        ResendEmailService.send_email(
          to: entry.email,
          subject: "You're on the list — Ultimate Social Media",
          html_content: html_content
        )
      rescue => e
        Rails.logger.error "Waitlist email failed: #{e.message}"
      end
    end

    redirect_to root_path, notice: "You're on the list!"

  rescue => e
    redirect_to root_path, alert: "Something went wrong, please try again."
  end
end
