require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)
require_relative '../lib/middleware/ultimate_social_media_health_check'
require_relative '../lib/env_checker'

require 'open-uri'

module Myapp
  class Application < Rails::Application

    # check environment variables in production
    # Disabled for Railway - Railway provides variables at runtime
    # EnvChecker.check_required_env_vars if Rails.env.production?

    config.generators do |g|
      g.test_framework :rspec,
        fixtures: true,
        view_specs: false,
        helper_specs: false,
        routing_specs: false,
        controller_specs: false,
        request_specs: false
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end

    # skip credentials
    config.require_master_key = false

    config.generators.assets = false
    config.generators.helper = false
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    config.autoload_lib(ignore: %w[assets tasks generators rails middleware source_mapping])
    config.middleware.insert_before Rails::Rack::Logger, UltimateSocialMediaHealthCheck

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Application name configuration
    config.x.appname = File.read(Rails.root.join('config', 'appname.txt')).strip

    # Postforme API key configuration
    config.x.postforme_api_key = ENV.fetch('ULTIMATE_POSTFORME_API_KEY', 'pfm_live_4NJHWqt7cUTpmVkXAqxCRa')

    # Use vips for Active Storage variants
    config.active_storage.variant_processor = :vips

    # Use custom MailDeliveryJob that inherits from ApplicationJob
    config.action_mailer.delivery_job = "MailDeliveryJob"

    # Configure GoodJob as the Active Job queue adapter
    config.active_job.queue_adapter = :good_job

    # Configure GoodJob - async mode for background job processing
    config.good_job.execution_mode = :async
    config.good_job.max_threads = 5

    # Disable cron temporarily for debugging
    # config.good_job.enable_cron = true
    # # Load cron configuration from recurring.yml
    # cron_config = Rails.application.config_for(:recurring)
    # config.good_job.cron = cron_config if cron_config.present?
  end
end
