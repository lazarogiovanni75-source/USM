# frozen_string_literal: true

# Configure ActiveStorage URL expiration
# S3 signed URLs expire after this time (default is 5 minutes, we extend to 1 hour)
Rails.application.config.active_storage.service_urls_expire_in = 1.hour

# Use redirect mode for S3 (generates signed URLs that work with private buckets)
Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_redirect
