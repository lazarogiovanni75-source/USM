class WaitlistController < ApplicationController
  def create
    @entry = WaitlistEmail.new(email: params[:email].to_s.strip.downcase)

    if @entry.save
      WaitlistMailer.confirmation_email(@entry).deliver_later
    end

    render :create
  end
end
