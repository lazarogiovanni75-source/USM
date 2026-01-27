class HomeController < ApplicationController
  include HomeDemoConcern

  def index
    # Redirect authenticated users to dashboard
    if current_user.present?
      redirect_to dashboards_path and return
    end
  end
end
