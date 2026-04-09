class WaitlistsController < ApplicationController
  before_action :authenticate_user!, except: [:new, :create]
  before_action :set_waitlist, only: [:show, :edit, :update, :destroy]

  def index
    @waitlists = WaitlistEmail.order(created_at: :desc)
  end

  def show
  end

  def new
    @waitlist = WaitlistEmail.new
  end

  def edit
  end

  def create
    @waitlist = WaitlistEmail.new(email: params.dig(:waitlist, :email) || params[:email])
    
    if @waitlist.save
      flash[:notice] = "Thank you for joining our waitlist!"
      redirect_to root_path
    else
      flash[:alert] = @waitlist.errors.full_messages.join(", ")
      redirect_to root_path
    end
  end

  def update
    if @waitlist.update(waitlist_params)
      flash[:notice] = "Waitlist entry updated"
      redirect_to waitlists_path
    else
      render :edit
    end
  end

  def destroy
    @waitlist.destroy
    flash[:notice] = "Waitlist entry removed"
    redirect_to waitlists_path
  end

  private

  def set_waitlist
    @waitlist = WaitlistEmail.find(params[:id])
  end

  def waitlist_params
    params.require(:waitlist).permit(:email, :status)
  end
end
