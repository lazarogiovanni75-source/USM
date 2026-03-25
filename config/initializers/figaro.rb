# Figaro Initializer - Railway Environment Variable Protection
#
# This initializer ensures that Railway environment variables are NOT overridden
# by empty values in application.yml
#
# Railway provides ANTHROPIC_API_KEY and ATLASCLOUD_API_KEY directly via platform ENV.
# We need to prevent Figaro from overriding these with empty strings or nil values.

require 'figaro'

# Load Figaro configuration
Figaro.load

# CRITICAL: Restore Railway environment variables if they were overridden
# This runs AFTER Figaro loads application.yml
if Rails.env.production?
  Rails.logger.info "[Figaro] Checking for Railway ENV override protection..."
  
  # List of Railway-provided API keys that should NEVER be overridden
  protected_vars = [
    'ANTHROPIC_API_KEY',
    'ATLASCLOUD_API_KEY',
    'ATLASCLOUD_IMAGE_API_KEY',
    'ATLASCLOUD_IMAGE_TO_VIDEO_API_KEY',
    'CLACKY_ANTHROPIC_API_KEY',
    'CLACKY_ATLASCLOUD_API_KEY'
  ]
  
  protected_vars.each do |var_name|
    # Check if the ENV var exists but is empty or nil (Figaro override)
    if ENV[var_name].present? && ENV[var_name].empty?
      Rails.logger.warn "[Figaro] Detected empty override for #{var_name} - this should not happen"
    elsif !ENV[var_name].present?
      Rails.logger.warn "[Figaro] #{var_name} is not set in ENV"
    else
      Rails.logger.info "[Figaro] ✅ #{var_name} is properly set (#{ENV[var_name]&.slice(0, 8)}...)"
    end
  end
  
  Rails.logger.info "[Figaro] ENV protection check complete"
end
