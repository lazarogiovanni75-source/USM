class HomeController < ApplicationController

  def index
    # Show landing page with waitlist to everyone
    # Authenticated users can still access dashboard via navbar
    @show_pending_approval = current_user.present? && !current_user.verified?
    render 'home/index'
  end

  def voice_assistant
    render 'shared/voice_assistant'
  end
end
