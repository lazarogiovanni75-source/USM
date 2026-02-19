# API controller for agency dashboard data
class Api::V1::AgencyController < Api::BaseController
  before_action :authenticate_user!
  before_action :ensure_agency_access

  # GET /api/v1/agency/dashboard
  def dashboard
    service = Analytics::AgencyDashboardService.new(current_user)
    
    render json: {
      clients: service.clients.map { |c| client_json(c) },
      campaigns_overview: service.campaigns_overview,
      tasks_overview: service.tasks_overview,
      alerts: service.alerts.limit(10),
      trending: Analytics::ViralDetector.get_all_trending(limit: 5).map { |v| viral_metric_json(v) }
    }
  end

  # GET /api/v1/agency/clients/:id
  def client
    service = Analytics::AgencyDashboardService.new(current_user)
    client_data = service.client_overview(params[:id])

    if client_data.nil?
      render json: { error: 'Client not found' }, status: :not_found
      return
    end

    render json: client_data.merge(
      trending: Analytics::ViralDetector.get_trending_for_client(params[:id], limit: 10).map { |v| viral_metric_json(v) }
    )
  end

  # GET /api/v1/agency/campaigns
  def campaigns
    service = Analytics::AgencyDashboardService.new(current_user)
    campaigns = Campaign.where(client_id: service.clients.pluck(:id))
                      .order(created_at: :desc)
                      .includes(:client, :user)
                      .limit(50)

    render json: campaigns.map { |c| campaign_json(c) }
  end

  # GET /api/v1/agency/trending
  def trending
    client_id = params[:client_id]
    trending = if client_id
      Analytics::ViralDetector.get_trending_for_client(client_id, limit: 20)
    else
      Analytics::ViralDetector.get_all_trending(limit: 20)
    end

    render json: trending.map { |v| viral_metric_json(v) }
  end

  # GET /api/v1/agency/viral-context
  # Returns viral context for AI integration
  def viral_context
    client_id = params[:client_id]
    context = Analytics::ViralDetector.get_viral_context_for_ai(client_id: client_id)

    render json: { context: context }
  end

  # GET /api/v1/agency/costs
  def costs
    service = Analytics::AgencyDashboardService.new(current_user)
    render json: { costs: service.cost_tracking }
  end

  private

  def ensure_agency_access
    unless current_user.agency_staff? || current_user.admin?
      render json: { error: 'Access denied' }, status: :forbidden
    end
  end

  def client_json(client)
    {
      id: client.id,
      name: client.name,
      status: client.status,
      plan: client.plan,
      monthly_budget: client.monthly_budget,
      total_campaigns: client.total_campaigns,
      active_campaigns: client.active_campaigns,
      created_at: client.created_at
    }
  end

  def campaign_json(campaign)
    {
      id: campaign.id,
      name: campaign.name,
      status: campaign.status,
      goal: campaign.goal,
      client_id: campaign.client_id,
      client_name: campaign.client&.name,
      user_name: campaign.user&.name,
      budget: campaign.budget,
      start_date: campaign.start_date,
      end_date: campaign.end_date,
      created_at: campaign.created_at
    }
  end

  def viral_metric_json(metric)
    {
      id: metric.id,
      scheduled_post_id: metric.scheduled_post_id,
      campaign_id: metric.campaign_id,
      client_id: metric.client_id,
      engagement_rate: metric.engagement_rate,
      share_velocity: metric.share_velocity,
      top_hashtags: metric.top_hashtags,
      is_viral: metric.is_viral,
      viral_rank: metric.viral_rank,
      detected_at: metric.detected_at,
      post: {
        content: metric.scheduled_post.content&.truncate(200),
        platform: metric.scheduled_post.platform,
        published_at: metric.scheduled_post.published_at
      }
    }
  end
end
