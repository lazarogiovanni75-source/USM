class Admin::DebugUsersController < ApplicationController
  DEBUG_TOKEN = 'debug123'
  
  before_action :verify_token
  
  def show
    render plain: \"User count: #{User.count}\\nFirst user email: #{User.first&.email || 'none'}\"
  end
  
  private
  
  def verify_token
    unless params[:token] == DEBUG_TOKEN
      render plain: 'Invalid token', status: :unauthorized
    end
  end
end
