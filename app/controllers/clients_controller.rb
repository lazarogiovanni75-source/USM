# Clients Controller for agency client management
class ClientsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_agency_or_admin, except: [:show]

  def index
    if current_user.agency_staff?
      @clients = Client.where(agency_user: current_user).or(
        Client.where(user: current_user)
      ).order(created_at: :desc)
    else
      @clients = Client.all.order(created_at: :desc)
    end
  end

  def show
    @client = Client.find(params[:id])
    authorize! :read, @client
  end

  def new
    @client = Client.new
  end

  def create
    @client = current_user.clients.build(client_params)
    @client.agency_user = current_user if current_user.agency_staff?
    
    if @client.save
      redirect_to client_path(@client), notice: 'Client was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @client = Client.find(params[:id])
    authorize! :update, @client
  end

  def update
    @client = Client.find(params[:id])
    authorize! :update, @client
    
    if @client.update(client_params)
      redirect_to client_path(@client), notice: 'Client was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @client = Client.find(params[:id])
    authorize! :destroy, @client
    
    @client.destroy
    redirect_to clients_url, notice: 'Client was successfully destroyed.'
  end

  private

  def client_params
    params.require(:client).permit(:name, :contact_name, :email, :phone, :address, :status, :plan, :monthly_budget, :notes)
  end

  def ensure_agency_or_admin
    unless current_user.agency_staff? || current_user.admin?
      redirect_to dashboard_path, alert: 'Access denied.'
    end
  end
end
