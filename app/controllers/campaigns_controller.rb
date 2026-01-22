class CampaignsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Write your real logic here
  end


  def show
    @campaign = current_user.campaigns.find(params[:id])
  end


  def new
    # Write your real logic here
  end


  def edit
    @campaign = current_user.campaigns.find(params[:id])
  end


  def create
    # Write your real logic here
  end


  def update
    # Write your real logic here
  end


  def destroy
    # Write your real logic here
  end

  private
  # Write your private methods here
end
