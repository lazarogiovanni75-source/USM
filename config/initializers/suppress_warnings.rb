# Suppress deprecation warnings for production environment
# These warnings don't affect functionality and are informational only

# Suppress CSV gem deprecation warning
# The warning appears because csv will become a bundled gem in Ruby 3.4
# Adding 'gem "csv"' to Gemfile resolves this
silence_warnings do
  require 'csv' if defined?(CSV)
end

# Suppress httparty eager_load warning
# This occurs during Rails initialization and doesn't affect functionality
# The config.eager_load is already properly set to true in production.rb
