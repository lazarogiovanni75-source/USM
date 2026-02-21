class HomeController < ApplicationController
  include HomeDemoConcern

  def index
    # Show landing page with waitlist to everyone
    # Authenticated users can still access dashboard via navbar
    @show_pending_approval = current_user.present? && !current_user.verified?
    render 'home/index'
  end
end
