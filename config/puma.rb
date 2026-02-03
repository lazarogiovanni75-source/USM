threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

# Use APP_PORT from environment, fallback to PORT, then default 3000
port ENV.fetch("PORT", "3000")

# Bind to 0.0.0.0 to accept connections from Railway's proxy
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', '3000')}"

plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
