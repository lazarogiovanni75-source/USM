# Runtime Environment Checker - Runs on every request
# This concern can be included in controllers to check ENV at request time

module RuntimeEnvChecker
  extend ActiveSupport::Concern

  included do
    before_action :log_runtime_env_status, if: -> { Rails.env.production? }
  end

  private

  def log_runtime_env_status
    Rails.logger.info "=" * 60
    Rails.logger.info "RUNTIME ENV CHECK (Request Time)"
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
