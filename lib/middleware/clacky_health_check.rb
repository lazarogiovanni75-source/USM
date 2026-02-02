# Middleware to handle health check requests from Clacky monitoring service and Railway
# Returns 200 OK immediately without logging or processing through Rails stack
class ClackyHealthCheck
  def initialize(app)
    @app = app
  end

  def call(env)
    # Check if this is a health check request
    request_path = env['PATH_INFO'].to_s
    user_agent = env['HTTP_USER_AGENT'].to_s

    # Respond to /up endpoint (Railway health checks) OR Clacky monitoring
    if request_path == '/up' || user_agent.match?(/clacky/i)
      # Return 200 OK immediately without further processing
      # No logging, no Rails stack, no database queries
      return [200, {'Content-Type' => 'text/plain'}, ['OK']]
    end

    # Pass through to the next middleware for all other requests
    @app.call(env)
  end
end
