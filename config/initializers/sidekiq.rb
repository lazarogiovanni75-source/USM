# frozen_string_literal: true

# Sidekiq Configuration
# Only load if Redis is available - prevents crashes on Railway without Redis

if ENV['REDIS_URL'].present?
  redis_url = ENV.fetch('REDIS_URL')

  Sidekiq.configure_server do |config|
    config.redis = { url: redis_url, size: Sidekiq[:concurrency].to_i }

    # Schedule sidekiq-cron jobs
    schedule_file = 'config/sidekiq_cron.yml'

    if File.exist?(schedule_file)
      Sidekiq::Cron::Job.load_from_hash(YAML.load_file(schedule_file, permitted_classes: [], permitted_symbols: [], aliases: true))
    end
  end

  Sidekiq.configure_client do |config|
    config.redis = { url: redis_url, size: 5 }
  end
else
  Rails.logger.info "[Sidekiq] REDIS_URL not configured - Sidekiq disabled"
end
