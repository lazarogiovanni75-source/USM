class WaitlistsController < ApplicationController
  # Anyone can sign up for the waitlist
  skip_before_action :authenticate_user!, only: [:create]

  # Admin: view all waitlist entries
  before_action :check_admin, except: [:create]

  def index
    @waitlists = Waitlist.order(created_at: :desc)
  end

  def new
    @waitlist = Waitlist.new
  end

  def show
    @waitlist = Waitlist.find(params[:id])
  end

  def edit
    @waitlist = Waitlist.find(params[:id])
  end

  def create
    @waitlist = Waitlist.new(waitlist_params)

    if @waitlist.save
      redirect_to root_path, notice: "You're on the list! We'll notify you when we launch."
    else
      redirect_to root_path(anchor: 'waitlist'), alert: @waitlist.errors.full_messages.join(", ")
    end
  end

  def update
    @waitlist = Waitlist.find(params[:id])
    if @waitlist.update(waitlist_params)
      redirect_to waitlist_path(@waitlist), notice: 'Waitlist entry was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @waitlist = Waitlist.find(params[:id])
    @waitlist.destroy
    redirect_to waitlists_path, notice: "Waitlist entry removed."
  end

  private

  def waitlist_params
    params.require(:waitlist).permit(:email)
  end

  def check_admin
    redirect_to root_path unless current_user&.admin?
  end
end
