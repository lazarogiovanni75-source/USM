class AutomationRulesService
  def initialize(user = nil)
    @user = user
  end

  # Create a new automation rule
  def create_rule(rule_params)
    rule = AutomationRule.new(rule_params.merge(user_id: @user.id))
    
    if rule.save
      # Validate the rule configuration
      validate_rule(rule)
    end
    
    rule
  end

  # Execute automation rules based on trigger events
  def execute_rules(event_type, trigger_data)
    rules = @user.automation_rules.active.where("trigger_events ?", event_type)
    results = []
    
    rules.each do |rule|
      if rule_matches_conditions?(rule, trigger_data)
        result = execute_rule_action(rule, trigger_data)
        results << result
        
        # Log the execution
        AutomationRuleExecution.create!(
          automation_rule: rule,
          trigger_data: trigger_data,
          status: result[:success] ? 'executed' : 'failed',
          execution_details: result
        )
      end
    end
    
    results
  end

  # Check if a rule matches its conditions
  def rule_matches_conditions?(rule, trigger_data)
    return true unless rule.conditions.any?

    rule.conditions.all? do |condition|
      evaluate_condition(condition, trigger_data)
    end
  end

  # Execute the action for a rule
  def execute_rule_action(rule, trigger_data)
    case rule.action_type
    when 'auto_schedule'
      execute_auto_schedule(rule, trigger_data)
    when 'auto_tag'
      execute_auto_tag(rule, trigger_data)
    when 'auto_notice'
      execute_auto_notice(rule, trigger_data)
    when 'auto_move'
      execute_auto_move(rule, trigger_data)
    when 'auto_ai_response'
      execute_auto_ai_response(rule, trigger_data)
    else
      { success: false, error: "Unknown action type: #{rule.action_type}" }
    end
  end

  # Get available rule templates
  def get_rule_templates
    [
      {
        id: 'auto_schedule_optimal',
        name: 'Auto-Schedule at Optimal Times',
        description: 'Automatically schedule posts during your optimal engagement hours',
        trigger_events: ['content_created'],
        action_type: 'auto_schedule',
        conditions: [],
        config: { optimal_only: true }
      },
      {
        id: 'high_engagement_notification',
        name: 'High Engagement Alert',
        description: 'Get notified when posts achieve high engagement',
        trigger_events: ['engagement_received'],
        action_type: 'auto_notice',
        conditions: [{ field: 'engagement_rate', operator: 'greater_than', value: 10 }],
        config: { notification_type: 'email' }
      },
      {
        id: 'content_quality_auto_tag',
        name: 'Auto-Tag Quality Content',
        description: 'Automatically tag content based on quality metrics',
        trigger_events: ['content_published'],
        action_type: 'auto_tag',
        conditions: [{ field: 'engagement_rate', operator: 'greater_than', value: 5 }],
        config: { tags: ['high-quality', 'trending'] }
      },
      {
        id: 'auto_move_drafts',
        name: 'Auto-Move Approved Drafts',
        description: 'Automatically move approved drafts to scheduled content',
        trigger_events: ['draft_approved'],
        action_type: 'auto_move',
        conditions: [{ field: 'status', operator: 'equals', value: 'approved' }],
        config: { target_status: 'scheduled' }
      },
      {
        id: 'ai_content_response',
        name: 'AI Auto-Response',
        description: 'Generate AI responses for high-engagement posts',
        trigger_events: ['engagement_received'],
        action_type: 'auto_ai_response',
        conditions: [{ field: 'engagement_rate', operator: 'greater_than', value: 8 }],
        config: { response_type: 'comment_reply' }
      },
      {
        id: 'weekly_content_review',
        name: 'Weekly Content Review',
        description: 'Automatically review and tag content performance weekly',
        trigger_events: ['weekly_summary'],
        action_type: 'auto_tag',
        conditions: [],
        config: { tags: ['weekly-review', 'performance-analyzed'] }
      }
    ]
  end

  # Validate rule configuration
  def validate_rule(rule)
    errors = []
    
    # Validate trigger events
    unless rule.trigger_events.any?
      errors << "At least one trigger event is required"
    end
    
    # Validate action type
    valid_actions = %w[auto_schedule auto_tag auto_notice auto_move auto_ai_response]
    unless valid_actions.include?(rule.action_type)
      errors << "Invalid action type: #{rule.action_type}"
    end
    
    # Validate conditions
    rule.conditions.each do |condition|
      valid_fields = %w[engagement_rate status content_type platform created_at]
      unless valid_fields.include?(condition[:field])
        errors << "Invalid condition field: #{condition[:field]}"
      end
      
      valid_operators = %w[equals greater_than less_than contains starts_with ends_with]
      unless valid_operators.include?(condition[:operator])
        errors << "Invalid condition operator: #{condition[:operator]}"
      end
    end
    
    if errors.any?
      rule.errors.add(:base, errors.join(', '))
      false
    else
      true
    end
  end

  # Get rule execution statistics
  def get_rule_statistics(days = 30)
    executions = AutomationRuleExecution.joins(:automation_rule)
                    .where(automation_rules: { user_id: @user.id })
                    .where('automation_rule_executions.created_at >= ?', days.days.ago)
                    .group(:status)
                    .count
    
    {
      total_executions: executions.values.sum,
      successful_executions: executions['executed'] || 0,
      failed_executions: executions['failed'] || 0,
      success_rate: executions.values.sum > 0 ? ((executions['executed'] || 0).to_f / executions.values.sum * 100).round(2) : 0
    }
  end

  private

  # Execute auto-scheduling
  def execute_auto_schedule(rule, trigger_data)
    content = trigger_data[:content]
    return { success: false, error: 'No content provided' } unless content

    # Find optimal time for scheduling
    optimal_time = find_optimal_scheduling_time(content)
    
    if optimal_time
      content.update(scheduled_for: optimal_time)
      { success: true, action: 'scheduled', scheduled_for: optimal_time }
    else
      { success: false, error: 'No optimal time found' }
    end
  end

  # Execute auto-tagging
  def execute_auto_tag(rule, trigger_data)
    content = trigger_data[:content] || trigger_data[:post]
    return { success: false, error: 'No content provided' } unless content

    tags = rule.config['tags'] || []
    tags.each do |tag|
      content.tags << tag unless content.tags.include?(tag)
    end
    
    content.save if content.changed?
    { success: true, action: 'tagged', tags: tags }
  end

  # Execute auto-notification
  def execute_auto_notice(rule, trigger_data)
    notification_type = rule.config['notification_type'] || 'in_app'
    
    case notification_type
    when 'email'
      # Send email notification
      NotificationMailer.automation_trigger(@user, rule, trigger_data).deliver_later
    when 'slack'
      # Send Slack notification (would integrate with webhook)
      # This would require external service setup
    end
    
    { success: true, action: 'notified', type: notification_type }
  end

  # Execute auto-move
  def execute_auto_move(rule, trigger_data)
    content = trigger_data[:content] || trigger_data[:draft]
    return { success: false, error: 'No content provided' } unless content

    target_status = rule.config['target_status'] || 'scheduled'
    content.update(status: target_status)
    
    { success: true, action: 'moved', from: content.status_before_last_save, to: target_status }
  end

  # Execute AI auto-response
  def execute_auto_ai_response(rule, trigger_data)
    content = trigger_data[:content] || trigger_data[:post]
    return { success: false, error: 'No content provided' } unless content

    response_type = rule.config['response_type'] || 'comment_reply'
    
    # Generate AI response
    ai_service = AiChatService.new(@user)
    prompt = "Generate a #{response_type} for this content: #{content.title}"
    
    response = ai_service.generate_response(prompt)
    
    if response[:success]
      # Store the AI response
      AiResponse.create!(
        content: content,
        response_type: response_type,
        ai_generated_text: response[:response],
        trigger_rule: rule
      )
      
      { success: true, action: 'ai_responded', response: response[:response] }
    else
      { success: false, error: response[:error] }
    end
  end

  # Evaluate individual conditions
  def evaluate_condition(condition, trigger_data)
    field = condition[:field]
    operator = condition[:operator]
    expected_value = condition[:value]
    
    actual_value = case field
    when 'engagement_rate'
      trigger_data[:engagement_rate] || 0
    when 'status'
      (trigger_data[:content] || trigger_data[:post])&.status
    when 'content_type'
      (trigger_data[:content] || trigger_data[:post])&.content_type
    when 'platform'
      trigger_data[:platform]
    when 'created_at'
      (trigger_data[:content] || trigger_data[:post])&.created_at
    else
      nil
    end
    
    case operator
    when 'equals'
      actual_value == expected_value
    when 'greater_than'
      actual_value.to_f > expected_value.to_f
    when 'less_than'
      actual_value.to_f < expected_value.to_f
    when 'contains'
      actual_value.to_s.include?(expected_value.to_s)
    when 'starts_with'
      actual_value.to_s.start_with?(expected_value.to_s)
    when 'ends_with'
      actual_value.to_s.end_with?(expected_value.to_s)
    else
      false
    end
  end

  # Find optimal scheduling time
  def find_optimal_scheduling_time(content)
    # Get user's historical performance data
    performance_data = PerformanceMetric.joins(:content)
                                      .where(contents: { user_id: @user.id })
                                      .where('performance_metrics.created_at >= ?', 30.days.ago)
                                      .group('EXTRACT(hour FROM contents.scheduled_for)')
                                      .average(:engagement_rate)
    
    if performance_data.any?
      best_hour = performance_data.max_by { |_hour, engagement| engagement }[0]
      
      # Schedule for next occurrence of best hour
      next_occurrence = Time.current
      while next_occurrence.hour != best_hour.to_i
        next_occurrence += 1.hour
      end
      
      # Ensure it's at least 1 hour from now
      next_occurrence = [next_occurrence + 1.hour, next_occurrence].max
      
      next_occurrence
    else
      # Default to 2 hours from now
      Time.current + 2.hours
    end
  end
end