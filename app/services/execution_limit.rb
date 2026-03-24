# Execution Limit Service - Prevent runaway tool execution
#
# Tracks tool calls per session to prevent infinite loops
# Limits: max calls, timeout, cost ceiling
class ExecutionLimit
  DEFAULT_MAX_CALLS = 5
  DEFAULT_TIMEOUT_SECONDS = 30
  DEFAULT_COST_CENT = 100 # $1.00 max per session

  # Session key for storing execution state
  def self.session_key
    "ai_execution_limits"
  end

  # Check if execution should proceed
  def self.can_execute?(session, tool_name = nil)
    limits = get_limits(session)

    # Check call count
    if limits[:call_count] >= limits[:max_calls]
      Rails.logger.warn "[ExecutionLimit] Max calls reached: #{limits[:call_count]}/#{limits[:max_calls]}"
      return false
    end

    # Check timeout
    if limits[:started_at] && (Time.current - limits[:started_at]) > limits[:timeout_seconds]
      Rails.logger.warn "[ExecutionLimit] Timeout reached"
      return false
    end

    # Check cost
    if limits[:total_cost] >= limits[:cost_ceiling]
      Rails.logger.warn "[ExecutionLimit] Cost ceiling reached: #{limits[:total_cost]}/#{limits[:cost_ceiling]}"
      return false
    end

    true
  end

  # Record a tool execution
  def self.record_execution(session, tool_name, cost = 0)
    limits = get_limits(session)

    new_limits = {
      call_count: limits[:call_count] + 1,
      total_cost: limits[:total_cost] + cost,
      started_at: limits[:started_at] || Time.current,
      max_calls: limits[:max_calls],
      timeout_seconds: limits[:timeout_seconds],
      cost_ceiling: limits[:cost_ceiling],
      tool_history: (limits[:tool_history] || []) + [{ tool: tool_name, at: Time.current }]
    }

    set_limits(session, new_limits)
    new_limits
  end

  # Get current execution state
  def self.get_state(session)
    get_limits(session)
  end

  # Reset execution limits for a new session
  def self.reset(session)
    Rails.cache.delete(session_key_for(session))
  end

  # Set custom limits
  def self.set_custom_limits(session, options = {})
    limits = get_limits(session)
    new_limits = limits.merge(options)
    set_limits(session, new_limits)
  end

  private

  def self.get_limits(session)
    key = session_key_for(session)
    Rails.cache.read(key) || default_limits
  end

  def self.set_limits(session, limits)
    key = session_key_for(session)
    Rails.cache.write(key, limits, expires_in: 1.hour)
  end

  def self.session_key_for(session)
    "#{session_key}_#{session.id}"
  end

  def self.default_limits
    {
      call_count: 0,
      total_cost: 0,
      started_at: nil,
      max_calls: DEFAULT_MAX_CALLS,
      timeout_seconds: DEFAULT_TIMEOUT_SECONDS,
      cost_ceiling: DEFAULT_COST_CENT,
      tool_history: []
    }
  end
end
