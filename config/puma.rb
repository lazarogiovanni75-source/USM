threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

# Specifies the `environment` that Puma will run in.
environment ENV.fetch("RAILS_ENV", "production")

# Bind to 0.0.0.0 to accept connections from deployment platform
# Use PORT environment variable (Railway provides this automatically)
port_number = ENV.fetch("PORT", "3000")
bind "tcp://0.0.0.0:#{port_number}"

puts "Puma starting on port #{port_number}"

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
