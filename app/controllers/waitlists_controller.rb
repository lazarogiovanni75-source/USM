class WaitlistController < ApplicationController
  def create
    ensure_table_exists
    @entry = WaitlistEmail.new(email: params[:email].to_s.strip.downcase)

    if @entry.save
      WaitlistMailer.confirmation_email(@entry).deliver_later rescue nil
    end

    render :create
  end

  private

  def ensure_table_exists
    unless ActiveRecord::Base.connection.table_exists?(:waitlist_emails)
      ActiveRecord::Base.connection.create_table :waitlist_emails do |t|
        t.string :email, null: false
        t.string :status, default: 'pending'
        t.timestamps
      end
      ActiveRecord::Base.connection.add_index :waitlist_emails, :email, unique: true rescue nil
    end
  end
end
