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
      WaitlistMailer.confirmation_email(entry).deliver_later rescue nil
    end

    redirect_to root_path, notice: "You're on the list!"

  rescue => e
    redirect_to root_path, alert: "Something went wrong, please try again."
  end
end
