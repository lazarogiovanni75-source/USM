module Rails
  class HealthController < ActionController::Base
    skip_before_action :verify_authenticity_token
    
    def show
      render plain: "OK", status: :ok
    end
  end
end
