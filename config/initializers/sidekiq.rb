# frozen_string_literal: true

# Sidekiq Configuration
# Requires Redis - set REDIS_URL in environment variables

redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')

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
