require "active_support/core_ext/integer/time"

# Ensure SECRET_KEY_BASE is set (required for production)
ENV["SECRET_KEY_BASE"] ||= Rails.application.credentials.secret_key_base

Rails.application.configure do
  # CRITICAL: Set eager_load FIRST to avoid Rails 7.2 initialization errors
  config.eager_load = true

  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Enable serving static files
  config.public_file_server.enabled = true

  # Asset pipeline settings
  config.assets.compile = false
  config.assets.digest = true
  
  # Asset pipeline settings for Propshaft
  # Assets are pre-built by npm to public/assets/ and served from /assets/
  config.assets.prefix = "/assets"

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files in S3
  storage_name = ENV["STORAGE_BUCKET_NAME"] || ENV["S3_BUCKET_NAME"] || ENV["ULTIMATE_STORAGE_BUCKET_NAME"]
  storage_key = ENV["STORAGE_BUCKET_ACCESS_KEY_ID"] || ENV["AWS_ACCESS_KEY_ID"] || ENV["ULTIMATE_STORAGE_BUCKET_ACCESS_KEY_ID"]
  storage_secret = ENV["STORAGE_BUCKET_SECRET_ACCESS_KEY"] || ENV["AWS_SECRET_ACCESS_KEY"] || ENV["ULTIMATE_STORAGE_BUCKET_SECRET_ACCESS_KEY"]
  storage_region = ENV["STORAGE_BUCKET_REGION"] || ENV["AWS_REGION"] || ENV["ULTIMATE_STORAGE_BUCKET_REGION"]

  config.active_storage.service = (storage_name.present? && storage_key.present?) ? :amazon : :local
  Rails.logger&.info "Storage: Using #{config.active_storage.service} (bucket: #{storage_name&.first(20)})"

  # Mount Action Cable outside main process or domain.
  config.action_cable.disable_request_forgery_protection = true
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  host_and_port_and_protocol = EnvChecker.get_public_host_and_port_and_protocol
  # Use Rails.application.routes not config.default_url_options
  Rails.application.routes.default_url_options = host_and_port_and_protocol
  config.action_mailer.default_url_options = host_and_port_and_protocol

  # SMTP configuration for SendGrid
  smtp_password = ENV["SENDGRID_API_KEY"] || ENV["EMAIL_SMTP_PASSWORD"] || ENV["SMTP_PASSWORD"]
  smtp_address = ENV["EMAIL_SMTP_ADDRESS"] || ENV["SENDGRID_HOST"] || "smtp.sendgrid.net"
  smtp_port = ENV["EMAIL_SMTP_PORT"] || ENV["SMTP_PORT"] || "587"
  smtp_username = ENV["EMAIL_SMTP_USERNAME"] || ENV["SMTP_USERNAME"] || "apikey"

  if smtp_password.present? && smtp_address.present?
    config.action_mailer.smtp_settings = {
      address: smtp_address,
      port: smtp_port.presence || 587,
      authentication: :login,
      user_name: smtp_username.presence || 'apikey',
      password: smtp_password,
      enable_starttls_auto: true,
      openssl_verify_mode: 'peer'
    }
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = false
    Rails.logger&.info "Email: SMTP configured with #{smtp_address}"
  else
    # Fallback to test mode if SMTP not configured
    config.action_mailer.delivery_method = :test
    Rails.logger&.warn "Email: SMTP not configured - using test mode. EMAIL_SMTP_PASSWORD=#{ENV['EMAIL_SMTP_PASSWORD']&.first(8)}"
  end

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = false  # Disabled for Railway - Railway handles SSL at proxy level

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Ultimate Social Media: Enable caching
  config.cache_store = :memory_store

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter = :resque
  # config.active_job.queue_name_prefix = "myapp_production"

  # Enable GoodJob for background job processing
  # Using :async for production to handle emails in background
  config.good_job.execution_mode = :async

  # Disable caching for Action Mailer templates even if Action Controller
  # caching is enabled.
  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Disable host authorization temporarily for testing
  config.host_authorization = { exclude: ->(request) { true } }
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
