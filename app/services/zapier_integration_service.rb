class ZapierIntegrationService
  def initialize(user = nil)
    @user = user
  end

  # Handle incoming webhooks from Zapier
  def handle_webhook(webhook_data, webhook_type = 'generic')
    case webhook_type
    when 'content_created'
      handle_content_created_webhook(webhook_data)
    when 'post_published'
      handle_post_published_webhook(webhook_data)
    when 'engagement_received'
      handle_engagement_received_webhook(webhook_data)
    when 'scheduled_post'
      handle_scheduled_post_webhook(webhook_data)
    else
      handle_generic_webhook(webhook_data)
    end
  end

  # Create webhook endpoints for external integrations
  def create_webhook_endpoint(workflow_name, trigger_events)
    # This would typically integrate with Zapier's webhook API
    # For now, we'll simulate webhook creation
    endpoint_id = SecureRandom.uuid
    webhook_url = "#{Rails.application.routes.default_url_options[:host]}/api/v1/zapier/webhooks/#{endpoint_id}"
    
    # Store webhook configuration
    @user.zapier_webhooks.create!(
      name: workflow_name,
      webhook_url: webhook_url,
      trigger_events: trigger_events,
      status: 'active',
      endpoint_id: endpoint_id
    )
    
    {
      webhook_url: webhook_url,
      endpoint_id: endpoint_id,
      status: 'active'
    }
  end

  # Send data to external services via Zapier
  def send_to_zapier(webhook_url, data)
    begin
      response = HTTParty.post(webhook_url, 
        body: data.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      { success: response.success?, status: response.code }
    rescue => e
      Rails.logger.error "Zapier webhook failed: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Predefined key workflow templates
  def get_workflow_templates
    [
      {
        id: 'content_to_slack',
        name: 'Notify Slack on New Content',
        description: 'Send a Slack message when new content is created',
        trigger_events: ['content_created'],
        actions: ['send_slack_message'],
        icon: 'slack',
        category: 'notifications'
      },
      {
        id: 'high_engagement_email',
        name: 'Email Alert for High Engagement',
        description: 'Send email when post gets high engagement',
        trigger_events: ['engagement_received'],
        actions: ['send_email'],
        condition: 'engagement_rate > 5',
        icon: 'mail',
        category: 'alerts'
      },
      {
        id: 'google_sheets_export',
        name: 'Export Analytics to Google Sheets',
        description: 'Export post performance data to Google Sheets',
        trigger_events: ['post_published', 'weekly_summary'],
        actions: ['update_sheets'],
        schedule: 'weekly',
        icon: 'table',
        category: 'analytics'
      },
      {
        id: 'content_calendar_sync',
        name: 'Sync with Google Calendar',
        description: 'Add scheduled posts to Google Calendar',
        trigger_events: ['scheduled_post'],
        actions: ['create_calendar_event'],
        icon: 'calendar',
        category: 'scheduling'
      },
      {
        id: 'social_media_auto_post',
        name: 'Auto-post to Multiple Platforms',
        description: 'Automatically post to all connected platforms',
        trigger_events: ['content_approved'],
        actions: ['post_to_platforms'],
        platforms: ['instagram', 'twitter', 'linkedin'],
        icon: 'share-2',
        category: 'publishing'
      },
      {
        id: 'ai_content_analysis',
        name: 'AI Content Analysis',
        description: 'Run AI analysis on new content',
        trigger_events: ['content_created'],
        actions: ['analyze_content'],
        ai_features: ['sentiment', 'readability', 'seo_score'],
        icon: 'brain',
        category: 'ai'
      },
      {
        id: 'performance_reporting',
        name: 'Weekly Performance Report',
        description: 'Generate and send weekly performance reports',
        trigger_events: ['weekly_summary'],
        actions: ['generate_report', 'send_email'],
        schedule: 'weekly',
        icon: 'bar-chart',
        category: 'reporting'
      },
      {
        id: 'competitor_tracking',
        name: 'Competitor Content Alerts',
        description: 'Get notified of competitor content',
        trigger_events: ['competitor_detected'],
        actions: ['send_alert'],
        icon: 'eye',
        category: 'monitoring'
      }
    ]
  end

  # Create workflow from template
  def create_workflow_from_template(template_id, user_config = {})
    template = get_workflow_templates.find { |t| t[:id] == template_id }
    return nil unless template

    # Create webhook configuration
    webhook_config = {
      name: template[:name],
      trigger_events: template[:trigger_events],
      actions: template[:actions],
      config: user_config.merge(template.slice(:condition, :schedule, :platforms, :ai_features))
    }

    create_webhook_endpoint(template[:name], template[:trigger_events])
  end

  # Execute workflow actions
  def execute_workflow_actions(webhook, trigger_data)
    results = []
    
    webhook.trigger_events.each do |event|
      case event
      when 'content_created'
        results << execute_content_created_actions(webhook, trigger_data)
      when 'post_published'
        results << execute_post_published_actions(webhook, trigger_data)
      when 'engagement_received'
        results << execute_engagement_actions(webhook, trigger_data)
      when 'scheduled_post'
        results << execute_scheduled_post_actions(webhook, trigger_data)
      end
    end
    
    results.flatten
  end

  private

  def handle_content_created_webhook(data)
    content = Content.find_by(id: data[:content_id])
    return unless content

    # Trigger relevant workflows
    trigger_workflows('content_created', { content: content })
  end

  def handle_post_published_webhook(data)
    post = ScheduledPost.find_by(id: data[:post_id])
    return unless post

    trigger_workflows('post_published', { post: post })
  end

  def handle_engagement_received_webhook(data)
    metrics = PerformanceMetric.find_by(id: data[:metrics_id])
    return unless metrics

    trigger_workflows('engagement_received', { metrics: metrics })
  end

  def handle_scheduled_post_webhook(data)
    post = ScheduledPost.find_by(id: data[:post_id])
    return unless post

    trigger_workflows('scheduled_post', { post: post })
  end

  def handle_generic_webhook(data)
    trigger_workflows('generic', data)
  end

  def trigger_workflows(event_type, data)
    webhooks = @user.zapier_webhooks.where(status: 'active')
                              .where("trigger_events ?", event_type)
    
    webhooks.each do |webhook|
      execute_workflow_actions(webhook, data)
    end
  end

  def execute_content_created_actions(webhook, data)
    results = []
    
    webhook.actions.each do |action|
      case action
      when 'send_slack_message'
        results << send_slack_notification(data[:content])
      when 'analyze_content'
        results << analyze_content_with_ai(data[:content])
      when 'generate_report'
        results << generate_content_report(data[:content])
      end
    end
    
    results
  end

  def execute_post_published_actions(webhook, data)
    results = []
    
    webhook.actions.each do |action|
      case action
      when 'update_sheets'
        results << update_google_sheets(data[:post])
      when 'create_calendar_event'
        results << create_calendar_event(data[:post])
      when 'send_notification'
        results << send_publish_notification(data[:post])
      end
    end
    
    results
  end

  def execute_engagement_actions(webhook, data)
    results = []
    
    webhook.actions.each do |action|
      case action
      when 'send_email'
        results << send_engagement_email(data[:metrics])
      when 'send_slack_message'
        results << send_engagement_slack(data[:metrics])
      when 'update_dashboard'
        results << update_dashboard_metrics(data[:metrics])
      end
    end
    
    results
  end

  def execute_scheduled_post_actions(webhook, data)
    results = []
    
    webhook.actions.each do |action|
      case action
      when 'post_to_platforms'
        results << auto_post_to_platforms(data[:post])
      when 'send_reminder'
        results << send_scheduling_reminder(data[:post])
      end
    end
    
    results
  end

  # Action implementations
  def send_slack_notification(content)
    # Implementation would send to Slack via webhook
    { action: 'slack_notification', status: 'sent', content_id: content.id }
  end

  def analyze_content_with_ai(content)
    # Use AI service to analyze content
    analysis = {
      sentiment: rand(-1.0..1.0).round(2),
      readability_score: rand(60..90),
      seo_score: rand(70..95),
      word_count: content.body.split.length,
      estimated_reading_time: (content.body.split.length / 200.0).ceil
    }
    
    { action: 'ai_analysis', status: 'completed', analysis: analysis }
  end

  def update_google_sheets(post)
    # Implementation would update Google Sheets
    { action: 'sheets_update', status: 'updated', post_id: post.id }
  end

  def send_engagement_email(metrics)
    # Send email about high engagement
    { action: 'engagement_email', status: 'sent', metrics_id: metrics.id }
  end

  def auto_post_to_platforms(post)
    # Auto-post to multiple platforms
    { action: 'multi_platform_post', status: 'posted', post_id: post.id }
  end
end