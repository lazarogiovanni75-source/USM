class AutoResponseTriggersService
  def initialize(user = nil)
    @user = user
  end

  # Create a new auto-response trigger
  def create_trigger(trigger_params)
    trigger = AutoResponseTrigger.new(trigger_params.merge(user_id: @user.id))
    
    if trigger.save
      validate_trigger(trigger)
    end
    
    trigger
  end

  # Execute auto-response triggers based on engagement events
  def execute_triggers(event_type, engagement_data)
    triggers = @user.auto_response_triggers.active.where(trigger_type: event_type)
    results = []
    
    triggers.each do |trigger|
      if trigger_matches_conditions?(trigger, engagement_data)
        result = execute_trigger_response(trigger, engagement_data)
        results << result
        
        # Log the execution
        trigger.trigger_executions.create!(
          engagement_data: engagement_data,
          status: result[:success] ? 'executed' : 'failed',
          response_data: result
        )
      end
    end
    
    results
  end

  # Check if a trigger matches its conditions
  def trigger_matches_conditions?(trigger, engagement_data)
    return true unless trigger.conditions.any?

    trigger.conditions.all? do |condition|
      evaluate_response_condition(condition, engagement_data)
    end
  end

  # Execute the response for a trigger
  def execute_trigger_response(trigger, engagement_data)
    case trigger.response_type
    when 'ai_comment'
      execute_ai_comment_response(trigger, engagement_data)
    when 'ai_dm'
      execute_ai_dm_response(trigger, engagement_data)
    when 'auto_like'
      execute_auto_like(trigger, engagement_data)
    when 'auto_follow'
      execute_auto_follow(trigger, engagement_data)
    when 'ai_thank_you'
      execute_ai_thank_you_response(trigger, engagement_data)
    when 'custom_template'
      execute_custom_template_response(trigger, engagement_data)
    else
      { success: false, error: "Unknown response type: #{trigger.response_type}" }
    end
  end

  # Get available trigger templates
  def get_trigger_templates
    [
      {
        id: 'thank_you_comments',
        name: 'Thank You for Comments',
        description: 'Automatically respond with a thank you message to comments',
        trigger_type: 'comment_received',
        response_type: 'ai_thank_you',
        conditions: [],
        config: { tone: 'friendly', include_emoji: true }
      },
      {
        id: 'ai_engagement_responses',
        name: 'AI-Powered Engagement Responses',
        description: 'Generate contextual AI responses to engagement',
        trigger_type: 'engagement_received',
        response_type: 'ai_comment',
        conditions: [{ field: 'engagement_rate', operator: 'greater_than', value: 5 }],
        config: { response_style: 'professional', max_length: 150 }
      },
      {
        id: 'auto_like_back',
        name: 'Auto-Like Back',
        description: 'Automatically like posts from users who like your content',
        trigger_type: 'like_received',
        response_type: 'auto_like',
        conditions: [],
        config: { delay_minutes: 5 }
      },
      {
        id: 'high_engagement_ai_response',
        name: 'High Engagement AI Response',
        description: 'Generate AI responses for high-engagement interactions',
        trigger_type: 'high_engagement',
        response_type: 'ai_comment',
        conditions: [{ field: 'engagement_score', operator: 'greater_than', value: 20 }],
        config: { response_style: 'engaging', max_length: 200 }
      },
      {
        id: 'personalized_dm',
        name: 'Personalized DM Response',
        description: 'Send personalized direct messages to valuable connections',
        trigger_type: 'dm_received',
        response_type: 'ai_dm',
        conditions: [{ field: 'follower_tier', operator: 'equals', value: 'premium' }],
        config: { response_style: 'personal', include_name: true }
      },
      {
        id: 'template_based_responses',
        name: 'Template-Based Responses',
        description: 'Use custom templates for consistent responses',
        trigger_type: 'engagement_received',
        response_type: 'custom_template',
        conditions: [],
        config: { template_id: nil, variable_substitution: true }
      }
    ]
  end

  # Validate trigger configuration
  def validate_trigger(trigger)
    errors = []
    
    # Validate response type
    valid_response_types = %w[ai_comment ai_dm auto_like auto_follow ai_thank_you custom_template]
    unless valid_response_types.include?(trigger.response_type)
      errors << "Invalid response type: #{trigger.response_type}"
    end
    
    # Validate trigger type
    valid_trigger_types = %w[comment_received like_received dm_received share_received mention_received high_engagement]
    unless valid_trigger_types.include?(trigger.trigger_type)
      errors << "Invalid trigger type: #{trigger.trigger_type}"
    end
    
    # Validate conditions
    trigger.conditions.each do |condition|
      valid_fields = %w[engagement_rate engagement_score follower_count follower_tier content_type platform time_of_day]
      unless valid_fields.include?(condition[:field])
        errors << "Invalid condition field: #{condition[:field]}"
      end
    end
    
    if errors.any?
      trigger.errors.add(:base, errors.join(', '))
      false
    else
      true
    end
  end

  # Get trigger execution statistics
  def get_trigger_statistics(days = 30)
    executions = @user.trigger_executions
                    .where('created_at >= ?', days.days.ago)
                    .group(:status)
                    .count
    
    {
      total_executions: executions.values.sum,
      successful_executions: executions['executed'] || 0,
      failed_executions: executions['failed'] || 0,
      success_rate: executions.values.sum > 0 ? ((executions['executed'] || 0).to_f / executions.values.sum * 100).round(2) : 0
    }
  end

  # Generate AI response for comments
  def generate_ai_response(content, engagement_type, custom_prompt = nil)
    ai_service = AiChatService.new(@user)
    
    base_prompt = case engagement_type
    when 'comment_received'
      "Generate a thoughtful and engaging response to this comment on your content."
    when 'like_received'
      "Generate a friendly thank you message for someone who liked your content."
    when 'share_received'
      "Generate an appreciative response for someone who shared your content."
    when 'mention_received'
      "Generate a professional response to being mentioned in a post."
    else
      "Generate an appropriate response for this engagement."
    end
    
    full_prompt = "#{base_prompt}\n\nContent: #{content.title}\nDescription: #{content.description}\n\n"
    full_prompt += custom_prompt if custom_prompt
    
    response = ai_service.generate_response(full_prompt)
    
    if response[:success]
      # Clean and format the response
      clean_response = response[:response].gsub(/[\r\n]+/, ' ').strip
      
      # Ensure it's not too long for social media
      max_length = 280 # Twitter limit
      clean_response = clean_response[0...max_length] + '...' if clean_response.length > max_length
      
      { success: true, response: clean_response, metadata: { type: 'ai_generated', length: clean_response.length } }
    else
      { success: false, error: response[:error] }
    end
  end

  private

  # Execute AI comment response
  def execute_ai_comment_response(trigger, engagement_data)
    content = engagement_data[:content]
    return { success: false, error: 'No content provided' } unless content

    custom_prompt = trigger.config['custom_prompt']
    response = generate_ai_response(content, trigger.trigger_type, custom_prompt)
    
    if response[:success]
      # Store the response for manual review if needed
      ai_response = AiResponse.create!(
        content: content,
        response_type: 'comment',
        ai_generated_text: response[:response],
        trigger: trigger,
        status: 'generated'
      )
      
      { success: true, action: 'ai_comment_generated', response_id: ai_response.id, response_text: response[:response] }
    else
      { success: false, error: response[:error] }
    end
  end

  # Execute AI DM response
  def execute_ai_dm_response(trigger, engagement_data)
    content = engagement_data[:content]
    return { success: false, error: 'No content provided' } unless content

    custom_prompt = trigger.config['custom_prompt']
    response = generate_ai_response(content, trigger.trigger_type, custom_prompt)
    
    if response[:success]
      # Store DM for sending
      dm_response = AutoResponse.create!(
        content: content,
        response_type: 'dm',
        ai_generated_text: response[:response],
        trigger: trigger,
        status: 'pending_send'
      )
      
      { success: true, action: 'ai_dm_prepared', response_id: dm_response.id, response_text: response[:response] }
    else
      { success: false, error: response[:error] }
    end
  end

  # Execute auto-like
  def execute_auto_like(trigger, engagement_data)
    # This would integrate with social media APIs
    # For now, we'll simulate the action
    
    { success: true, action: 'auto_liked', user_id: engagement_data[:engaging_user_id] }
  end

  # Execute auto-follow
  def execute_auto_follow(trigger, engagement_data)
    # This would integrate with social media APIs
    # For now, we'll simulate the action
    
    { success: true, action: 'auto_followed', user_id: engagement_data[:engaging_user_id] }
  end

  # Execute AI thank you response
  def execute_ai_thank_you_response(trigger, engagement_data)
    content = engagement_data[:content]
    return { success: false, error: 'No content provided' } unless content

    # Generate a thank you message
    thank_you_messages = [
      "Thank you so much for your comment! 😊",
      "Really appreciate your feedback! 🙏",
      "Thanks for taking the time to comment! ❤️",
      "Your comment made my day! ✨",
      "Thank you for the engaging conversation! 🚀"
    ]
    
    # Add emoji if configured
    include_emoji = trigger.config['include_emoji'] != false
    tone = trigger.config['tone'] || 'friendly'
    
    base_message = thank_you_messages.sample
    emoji = include_emoji ? " #{['😊', '🙏', '❤️', '✨', '🚀'].sample}" : ""
    
    final_message = case tone
    when 'professional'
      "Thank you for your thoughtful comment."
    when 'casual'
      "Thanks for the awesome comment!"
    else
      base_message + emoji
    end
    
    # Store the response
    thank_you_response = AutoResponse.create!(
      content: content,
      response_type: 'thank_you',
      ai_generated_text: final_message,
      trigger: trigger,
      status: 'generated'
    )
    
    { success: true, action: 'thank_you_generated', response_id: thank_you_response.id, response_text: final_message }
  end

  # Execute custom template response
  def execute_custom_template_response(trigger, engagement_data)
    content = engagement_data[:content]
    return { success: false, error: 'No content provided' } unless content

    template_id = trigger.config['template_id']
    template = @user.response_templates.find_by(id: template_id)
    
    unless template
      return { success: false, error: 'Template not found' }
    end
    
    # Substitute variables in template
    response_text = substitute_template_variables(template.body, content, engagement_data)
    
    # Store the response
    template_response = AutoResponse.create!(
      content: content,
      response_type: 'template',
      ai_generated_text: response_text,
      trigger: trigger,
      template: template,
      status: 'generated'
    )
    
    { success: true, action: 'template_response_generated', response_id: template_response.id, response_text: response_text }
  end

  # Evaluate response conditions
  def evaluate_response_condition(condition, engagement_data)
    field = condition[:field]
    operator = condition[:operator]
    expected_value = condition[:value]
    
    actual_value = case field
    when 'engagement_rate'
      engagement_data[:engagement_rate] || 0
    when 'engagement_score'
      engagement_data[:engagement_score] || 0
    when 'follower_count'
      engagement_data[:follower_count] || 0
    when 'follower_tier'
      engagement_data[:follower_tier] || 'regular'
    when 'content_type'
      engagement_data[:content]&.content_type
    when 'platform'
      engagement_data[:platform]
    when 'time_of_day'
      Time.current.hour
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

  # Substitute variables in template
  def substitute_template_variables(template_body, content, engagement_data)
    variables = {
      '{content_title}' => content.title,
      '{content_type}' => content.content_type,
      '{platform}' => engagement_data[:platform],
      '{user_name}' => engagement_data[:engaging_user_name] || 'there',
      '{engagement_type}' => engagement_data[:engagement_type],
      '{current_date}' => Date.current.strftime('%B %d, %Y')
    }
    
    substituted = template_body
    variables.each do |var, value|
      substituted = substituted.gsub(var, value.to_s)
    end
    
    substituted
  end
end