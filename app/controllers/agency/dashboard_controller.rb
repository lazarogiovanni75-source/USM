# Agency Dashboard Controller
# Provides multi-client management interface for agencies
class Agency::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_agency_access

  def index
    @dashboard_service = Analytics::AgencyDashboardService.new(current_user)
    @clients = @dashboard_service.clients
    @campaigns_overview = @dashboard_service.campaigns_overview
    @tasks_overview = @dashboard_service.tasks_overview
    @alerts = @dashboard_service.alerts.limit(5)
    @trending = Analytics::ViralDetector.get_all_trending(limit: 5)
  end

  def client
    @dashboard_service = Analytics::AgencyDashboardService.new(current_user)
    @client_data = @dashboard_service.client_overview(params[:id])
    
    if @client_data.nil?
      redirect_to agency_dashboard_path, alert: 'Client not found'
      return
    end
    
    @trending = Analytics::ViralDetector.get_trending_for_client(params[:id], limit: 10)
  end

  def campaigns
    @dashboard_service = Analytics::AgencyDashboardService.new(current_user)
    @campaigns = Campaign.where(client_id: @dashboard_service.clients.pluck(:id))
                       .order(created_at: :desc)
                       .includes(:client, :user)
  end

  def trending
    @dashboard_service = Analytics::AgencyDashboardService.new(current_user)
    @trending = Analytics::ViralDetector.get_all_trending(limit: 20)
    @client_id = params[:client_id]
    
    if @client_id
      @trending = Analytics::ViralDetector.get_trending_for_client(@client_id, limit: 20)
    end
  end

  def costs
    @dashboard_service = Analytics::AgencyDashboardService.new(current_user)
    @cost_data = @dashboard_service.cost_tracking
  end

  private

  def ensure_agency_access
    unless current_user.agency_staff? || current_user.admin?
      redirect_to dashboard_path, alert: 'Access denied. Agency staff only.'
    end
  end
end
