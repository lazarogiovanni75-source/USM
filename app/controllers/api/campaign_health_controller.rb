# frozen_string_literal: true

class Api::CampaignHealthController < ApplicationController
  before_action :authenticate_user!

  # GET /api/campaign_health/:id
  def show
    campaign = current_user.campaigns.find(params[:id])
    health = Analytics::CampaignHealthService.call(campaign)

    render json: health
  end

  # GET /api/campaign_health
  def index
    campaigns = current_user.campaigns
    health_data = Analytics::CampaignHealthService.batch_call(campaigns)

    render json: {
      campaigns: health_data,
      overall: Analytics::CampaignHealthService.overall_health
    }
  end
end
