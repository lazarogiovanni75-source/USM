# frozen_string_literal: true

# PolicySettingsService - User-configurable execution policies
# Manages approval rules, risk thresholds, and automation settings
#
# Usage:
#   policy = PolicySettingsService.new(user)
#   
#   # Check if tool requires approval
#   policy.requires_approval?(:schedule_post)
#   # => true/false
#
#   # Get user's risk threshold
#   policy.risk_threshold
#   # => :low, :medium, :high
#
#   # Update settings
#   policy.update_settings(auto_approve_low_risk: true, cost_approval_threshold: 100)
class PolicySettingsService
  DEFAULT_SETTINGS = {
    # Risk-based auto-approval
    auto_approve_low_risk: true,
    auto_approve_medium_risk: false,
    
    # Cost-based confirmation (in cents)
    cost_approval_threshold: 50,
    cost_auto_approve: true,
    
    # Specific tool approvals
    tool_specific_settings: {},
    
    # Execution limits
    max_daily_tool_calls: 50,
    max_monthly_cost_cents: 5000,
    
    # Notification preferences
    notify_on_medium_risk: true,
    notify_on_high_risk: true,
    notify_on_completion: false,
    notify_on_error: true,
    
    # Voice & automation
    enable_voice_commands: true,
    enable_scheduled_tasks: true,
    enable_auto_posting: false,
    
    # Confirmation preferences
    require_confirmation_for: %w[publish_post schedule_post create_post delete_content],
    skip_confirmation_for: %w[get_analytics get_campaigns generate_content_idea],
    
    # Safety
    enable_runaway_protection: true,
    max_concurrent_executions: 3,
    execution_timeout_seconds: 60
  }.freeze

  RISK_THRESHOLDS = {
    low: 0,
    medium: 25,
    high: 100
  }.freeze

  def initialize(user = nil)
    @user = user
    @settings = load_settings
  end

  # ==================== Approval Checks ====================

  # Check if a tool/action requires user approval
  # @param tool_name [Symbol/String] Name of the tool
  # @param options [Hash] Additional context (cost, risk_level, etc.)
  # @return [Boolean]
  def requires_approval?(tool_name, options = {})
    tool_name = tool_name.to_sym
    
    # Check explicit skip list first
    return false if @settings[:skip_confirmation_for]&.include?(tool_name.to_s)
    
    # Check explicit require list
    return true if @settings[:require_confirmation_for]&.include?(tool_name.to_s)
    
    # Check tool-specific setting
    tool_setting = @settings.dig(:tool_specific_settings, tool_name.to_s)
    return tool_setting[:require_approval] if tool_setting&.has_key?(:require_approval)
    
    # Check risk level
    risk = AiToolDefinitions.risk_level(tool_name)
    case risk
    when :low
      !@settings[:auto_approve_low_risk]
    when :medium
      !@settings[:auto_approve_medium_risk]
    when :high
      true # Always require approval for high risk
    end
  end

  # Check if cost exceeds approval threshold
  # @param cost_cents [Integer] Cost in cents
  # @return [Boolean]
  def requires_approval_for_cost?(cost_cents)
    return false if @settings[:cost_auto_approve]
    cost_cents > @settings[:cost_approval_threshold].to_i
  end

  # Check if user has hit execution limits
  # @param context [Hash] Current execution context
  # @return [Hash] { allowed: bool, reason: string, limit_type: string }
  def can_execute?(context = {})
    return { allowed: true, reason: nil, limit_type: nil } unless @settings[:enable_runaway_protection]
    
    # Check daily tool call limit
    daily_calls = AuditExecution.where(user: @user)
      .where('created_at >= ?', 1.day.ago)
      .count
    
    if daily_calls >= @settings[:max_daily_tool_calls].to_i
      return {
        allowed: false,
        reason: "Daily tool call limit reached (#{daily_calls}/#{@settings[:max_daily_tool_calls]})",
        limit_type: :daily_calls
      }
    end
    
    # Check monthly cost limit
    monthly_cost = AuditExecution.where(user: @user)
      .where('created_at >= ?', 1.month.ago)
      .sum(:cost_cents)
    
    if monthly_cost >= @settings[:max_monthly_cost_cents].to_i
      return {
        allowed: false,
        reason: "Monthly cost limit reached ($#{monthly_cost / 100.0}/$#{@settings[:max_monthly_cost_cents] / 100.0})",
        limit_type: :monthly_cost
      }
    end
    
    # Check concurrent executions
    concurrent = AuditExecution.where(user: @user)
      .where(status: %w[executing awaiting_confirmation])
      .count
    
    if concurrent >= @settings[:max_concurrent_executions].to_i
      return {
        allowed: false,
        reason: "Too many concurrent executions (#{concurrent}/#{@settings[:max_concurrent_executions]})",
        limit_type: :concurrent
      }
    end
    
    { allowed: true, reason: nil, limit_type: nil }
  end

  # ==================== Settings Access ====================

  # Get current risk threshold level
  def risk_threshold
    if @settings[:auto_approve_medium_risk] && !@settings[:auto_approve_low_risk]
      :medium
    elsif @settings[:auto_approve_low_risk]
      :low
    else
      :high
    end
  end

  # Get all current settings
  def settings
    @settings.dup
  end

  # Get a specific setting
  def get(key)
    @settings[key.to_sym]
  end

  # Check if a feature is enabled
  def feature_enabled?(feature)
    case feature
    when :voice_commands
      @settings[:enable_voice_commands]
    when :scheduled_tasks
      @settings[:enable_scheduled_tasks]
    when :auto_posting
      @settings[:enable_auto_posting]
    when :runaway_protection
      @settings[:enable_runaway_protection]
    else
      false
    end
  end

  # ==================== Settings Updates ====================

  # Update policy settings
  # @param new_settings [Hash] Settings to update
  # @return [Hash] Updated settings
  def update_settings(new_settings)
    # Validate settings
    validated = validate_settings(new_settings)
    
    # Merge with existing
    @settings.merge!(validated)
    
    # Save to user
    save_settings
    
    @settings
  end

  # Reset to default settings
  def reset_to_defaults
    @settings = DEFAULT_SETTINGS.dup
    save_settings
    @settings
  end

  # Set risk threshold (convenience method)
  # @param level [Symbol] :low, :medium, or :high
  def set_risk_threshold(level)
    case level
    when :low
      @settings[:auto_approve_low_risk] = true
      @settings[:auto_approve_medium_risk] = false
    when :medium
      @settings[:auto_approve_low_risk] = true
      @settings[:auto_approve_medium_risk] = true
    when :high
      @settings[:auto_approve_low_risk] = false
      @settings[:auto_approve_medium_risk] = false
    end
    save_settings
    @settings
  end

  # Enable/disable auto-approval for a specific tool
  # @param tool_name [String/Symbol]
  # @param auto_approve [Boolean]
  def set_tool_auto_approve(tool_name, auto_approve)
    @settings[:tool_specific_settings] ||= {}
    @settings[:tool_specific_settings][tool_name.to_s] ||= {}
    @settings[:tool_specific_settings][tool_name.to_s][:require_approval] = !auto_approve
    save_settings
    @settings
  end

  # ==================== Notifications ====================

  # Check if user should be notified for this event type
  def should_notify?(event_type)
    case event_type
    when :medium_risk_execution
      @settings[:notify_on_medium_risk]
    when :high_risk_execution
      @settings[:notify_on_high_risk]
    when :task_completion
      @settings[:notify_on_completion]
    when :task_error
      @settings[:notify_on_error]
    else
      false
    end
  end

  # ==================== Serialization ====================

  # Export settings as JSON
  def to_json
    @settings.to_json
  end

  # Export settings for API
  def to_api_response
    {
      risk_threshold: risk_threshold,
      settings: @settings,
      limits: {
        max_daily_tool_calls: @settings[:max_daily_tool_calls],
        max_monthly_cost_cents: @settings[:max_monthly_cost_cents],
        max_concurrent_executions: @settings[:max_concurrent_executions],
        execution_timeout_seconds: @settings[:execution_timeout_seconds]
      },
      features: {
        voice_commands: @settings[:enable_voice_commands],
        scheduled_tasks: @settings[:enable_scheduled_tasks],
        auto_posting: @settings[:enable_auto_posting],
        runaway_protection: @settings[:enable_runaway_protection]
      }
    }
  end

  private

  # Load settings from user or defaults
  def load_settings
    return DEFAULT_SETTINGS.dup unless @user

    if @user.respond_to?(:settings) && @user.settings.is_a?(Hash)
      user_settings = @user.settings[:policy_settings]
      DEFAULT_SETTINGS.merge(user_settings || {})
    else
      DEFAULT_SETTINGS.dup
    end
  end

  # Save settings to user
  def save_settings
    return false unless @user

    if @user.respond_to?(:settings)
      current = @user.settings.is_a?(Hash) ? @user.settings.dup : {}
      current[:policy_settings] = @settings
      @user.settings = current
      @user.save if @user.changed?
    end
  end

  # Validate incoming settings
  def validate_settings(new_settings)
    validated = {}
    
    # Boolean settings
    %i[
      auto_approve_low_risk auto_approve_medium_risk cost_auto_approve
      notify_on_medium_risk notify_on_high_risk notify_on_completion
      notify_on_error enable_voice_commands enable_scheduled_tasks
      enable_auto_posting enable_runaway_protection
    ].each do |key|
      validated[key] = new_settings[key] if [true, false].include?(new_settings[key])
    end
    
    # Numeric settings
    %i[cost_approval_threshold max_daily_tool_calls max_monthly_cost_cents
       max_concurrent_executions execution_timeout_seconds].each do |key|
      if new_settings[key].present?
        validated[key] = new_settings[key].to_i
      end
    end
    
    # Array settings
    %i[require_confirmation_for skip_confirmation_for].each do |key|
      validated[key] = new_settings[key] if new_settings[key].is_a?(Array)
    end
    
    # Tool-specific settings
    if new_settings[:tool_specific_settings].is_a?(Hash)
      validated[:tool_specific_settings] = new_settings[:tool_specific_settings]
    end
    
    validated
  end
end
