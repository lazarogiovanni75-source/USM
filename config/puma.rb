threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", "3000")

# Specifies the `environment` that Puma will run in.
environment ENV.fetch("RAILS_ENV", "production")

# Bind to 0.0.0.0 to accept connections from Railway's proxy
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', '3000')}"

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
