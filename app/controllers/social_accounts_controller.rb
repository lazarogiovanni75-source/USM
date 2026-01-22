class SocialAccountsController < ApplicationController
  before_action :authenticate_user!

  def index
    @social_accounts = current_user.social_accounts
  end


  def show
    @social_account = current_user.social_accounts.find(params[:id])
  end


  def new
    # Write your real logic here
  end


  def edit
    @social_account = current_user.social_accounts.find(params[:id])
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
