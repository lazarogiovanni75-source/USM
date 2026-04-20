class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  discard_on ActiveJob::DeserializationError

  # ⚠️  CRITICAL: DO NOT use `rescue` in subclass Jobs!
  # All exceptions are automatically caught here and reported to the frontend.
  # If you catch exceptions in your Job, they will be "swallowed" and not reported.
  # Let exceptions bubble up to this global handler.

  # Capture all job errors and broadcast to frontend via Turbo Streams
  rescue_from StandardError do |exception|
    # Broadcast error to frontend via GlobalErrorsChannel
    broadcast_job_error(exception)

    # Re-raise to allow normal error handling (retry, logging, etc.)
    raise exception
  end

  private

  def broadcast_job_error(exception)
    # Safely get backtrace with nil checks
    backtrace = exception.try(:backtrace)
    if backtrace.present?
      if Rails.respond_to?(:backtrace_cleaner) && Rails.backtrace_cleaner
        filtered = Rails.backtrace_cleaner.clean(backtrace)
        user_backtrace = filtered.any? ? filtered.first(10) : backtrace.first(10)
      else
        user_backtrace = backtrace.first(10)
      end
    else
      user_backtrace = []
    end

    error_data = {
      message: "#{exception.class}: #{exception.message}",
      job_class: self.class.name,
      job_id: job_id,
      queue: queue_name,
      exception_class: exception.class.name,
      backtrace: user_backtrace.join("\n")
    }

    # Broadcast error to system monitor channel
    ActionCable.server.broadcast("system_monitor", {
      type: 'job_error',
      html: "<turbo-stream action='report_async_error' target='system_monitor_errors'></turbo-stream>",
      error_data: error_data
    })
  rescue => broadcast_error
    # Silently fail if broadcast fails (don't disrupt job error handling)
    puts "[Job Error] Broadcast failed: #{broadcast_error.class} - #{broadcast_error.message}"
  end
end