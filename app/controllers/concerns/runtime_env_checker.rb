# Runtime Environment Checker - Runs on first request only
# This concern can be included in controllers to check ENV at request time

module RuntimeEnvChecker
  extend ActiveSupport::Concern

  included do
    before_action :log_runtime_env_status_once, if: -> { Rails.env.production? && !@env_checked }
  end

  private

  def log_runtime_env_status_once
    # Only log once per Rails instance (not on every request)
    return if defined?(@@env_checked_at_runtime)
    @@env_checked_at_runtime = true
    
    Rails.logger.info "=" * 60
    Rails.logger.info "FIRST REQUEST - RUNTIME ENV CHECK"
    Rails.logger.info "Time: #{Time.current.iso8601}"
    Rails.logger.info "=" * 60
    
    # Check Anthropic API Key
    anthropic_key = ENV['ANTHROPIC_API_KEY'].presence || ENV['CLACKY_ANTHROPIC_API_KEY'].presence
    if anthropic_key.present?
      Rails.logger.info "✅ ANTHROPIC_API_KEY: #{anthropic_key.slice(0, 8)}... (#{anthropic_key.length} chars)"
    else
      Rails.logger.error "❌ ANTHROPIC_API_KEY: MISSING"
      Rails.logger.error "   Available KEY vars: #{ENV.keys.select { |k| k.include?('KEY') || k.include?('SECRET') }.inspect}"
    end
    
    # Check Atlas Cloud API Key
    atlas_key = ENV['ATLASCLOUD_API_KEY'].presence || ENV['CLACKY_ATLASCLOUD_API_KEY'].presence
    if atlas_key.present?
      Rails.logger.info "✅ ATLASCLOUD_API_KEY: #{atlas_key.slice(0, 8)}... (#{atlas_key.length} chars)"
    else
      Rails.logger.warn "⚠️ ATLASCLOUD_API_KEY: MISSING"
    end
    
    # Check model
    model = ENV['ANTHROPIC_MODEL'].presence
    Rails.logger.info "📋 ANTHROPIC_MODEL: #{model || 'not set (using default)'}"
    
    Rails.logger.info "=" * 60
  end
end
