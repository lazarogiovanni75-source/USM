# frozen_string_literal: true

class PolicySettingsController < ApplicationController
  before_action :authenticate_user!

  def index
    @policy = PolicySettingsService.new(current_user)
  end

  def update
    @policy = PolicySettingsService.new(current_user)
    
    # Handle risk threshold separately
    if params[:risk_threshold].present?
      @policy.set_risk_threshold(params[:risk_threshold].to_sym)
    end
    
    # Handle other settings
    settings = params.permit!.to_h.except(:controller, :action, :id, :risk_threshold)
    @policy.update_settings(settings)
    
    redirect_to policy_settings_path, notice: 'Policy settings updated successfully.'
  rescue => e
    Rails.logger.error "Policy update error: #{e.message}"
    redirect_to policy_settings_path, alert: "Failed to update settings: #{e.message}"
  end

  def reset
    @policy = PolicySettingsService.new(current_user)
    @policy.reset_to_defaults
    
    redirect_to policy_settings_path, notice: 'Settings reset to defaults.'
  end
end
