class ScheduledAiTasksService
  def initialize(user = nil)
    @user = user
  end

  # Create a new scheduled AI task
  def create_task(task_params)
    task = ScheduledAiTask.new(task_params.merge(user_id: @user.id))
    
    if task.save
      validate_task(task)
    end
    
    task
  end

  # Execute scheduled tasks due for processing
  def execute_due_tasks
    due_tasks = @user.scheduled_ai_tasks.active.where('next_run_at <= ?', Time.current)
    results = []
    
    due_tasks.each do |task|
      result = execute_task(task)
      results << result
      
      # Schedule next execution if task is recurring
      schedule_next_execution(task) if task.recurring?
      
      # Log execution
      task.task_executions.create!(
        status: result[:success] ? 'executed' : 'failed',
        execution_data: result,
        started_at: Time.current
      )
    end
    
    results
  end

  # Execute individual task
  def execute_task(task)
    case task.task_type
    when 'content_generation'
      execute_content_generation_task(task)
    when 'performance_analysis'
      execute_performance_analysis_task(task)
    when 'trends_analysis'
      execute_trends_analysis_task(task)
    when 'ai_insights'
      execute_ai_insights_task(task)
    when 'content_optimization'
      execute_content_optimization_task(task)
    when 'engagement_analysis'
      execute_engagement_analysis_task(task)
    else
      { success: false, error: "Unknown task type: #{task.task_type}" }
    end
  end

  # Get available task templates
  def get_task_templates
    [
      {
        id: 'daily_content_generation',
        name: 'Daily Content Generation',
        description: 'Generate fresh content ideas every day',
        task_type: 'content_generation',
        schedule_type: 'daily',
        config: { topics: ['technology', 'lifestyle'], generation_count: 3 }
      },
      {
        id: 'weekly_performance_review',
        name: 'Weekly Performance Review',
        description: 'Analyze content performance weekly',
        task_type: 'performance_analysis',
        schedule_type: 'weekly',
        config: { analysis_depth: 'detailed', include_recommendations: true }
      },
      {
        id: 'daily_trends_monitor',
        name: 'Daily Trends Monitor',
        description: 'Monitor trending topics daily',
        task_type: 'trends_analysis',
        schedule_type: 'daily',
        config: { include_hashtags: true, save_to_drafts: true }
      },
      {
        id: 'biweekly_ai_insights',
        name: 'Bi-Weekly AI Insights',
        description: 'Generate AI-powered insights bi-weekly',
        task_type: 'ai_insights',
        schedule_type: 'biweekly',
        config: { insight_types: ['audience', 'content', 'engagement'] }
      },
      {
        id: 'weekly_content_optimization',
        name: 'Weekly Content Optimization',
        description: 'Optimize existing content weekly',
        task_type: 'content_optimization',
        schedule_type: 'weekly',
        config: { optimization_focus: 'engagement', max_content: 5 }
      },
      {
        id: 'daily_engagement_analysis',
        name: 'Daily Engagement Analysis',
        description: 'Analyze engagement patterns daily',
        task_type: 'engagement_analysis',
        schedule_type: 'daily',
        config: { platforms: 'all', include_predictions: true }
      }
    ]
  end

  # Validate task configuration
  def validate_task(task)
    errors = []
    
    # Validate task type
    valid_task_types = %w[content_generation performance_analysis trends_analysis ai_insights content_optimization engagement_analysis]
    unless valid_task_types.include?(task.task_type)
      errors << "Invalid task type: #{task.task_type}"
    end
    
    # Validate schedule
    valid_schedules = %w[once daily weekly monthly quarterly]
    unless valid_schedules.include?(task.schedule_type)
      errors << "Invalid schedule type: #{task.schedule_type}"
    end
    
    # Validate next_run_at
    if task.next_run_at && task.next_run_at < Time.current
      errors << "Next run time must be in the future"
    end
    
    if errors.any?
      task.errors.add(:base, errors.join(', '))
      false
    else
      true
    end
  end

  # Calculate next execution time
  def calculate_next_execution(task, current_time = Time.current)
    case task.schedule_type
    when 'daily'
      current_time + 1.day
    when 'weekly'
      current_time + 1.week
    when 'monthly'
      current_time + 1.month
    when 'quarterly'
      current_time + 3.months
    when 'once'
      nil
    else
      current_time + 1.day
    end
  end

  # Schedule next execution
  def schedule_next_execution(task)
    next_time = calculate_next_execution(task)
    task.update(next_run_at: next_time) if next_time
  end

  # Get task statistics
  def get_task_statistics(days = 30)
    executions = @user.task_executions
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

  private

  # Execute content generation task
  def execute_content_generation_task(task)
    topics = task.config['topics'] || ['general']
    generation_count = task.config['generation_count'] || 1
    
    ai_service = AiChatService.new(@user)
    generated_content = []
    
    generation_count.times do
      topic = topics.sample
      prompt = "Generate 3 creative content ideas about #{topic} for social media posts. Include engaging titles and brief descriptions."
      
      response = ai_service.generate_response(prompt)
      if response[:success]
        generated_content << {
          topic: topic,
          ideas: response[:response],
          generated_at: Time.current
        }
      end
    end
    
    # Save generated content as drafts
    generated_content.each do |content|
      Content.create!(
        user_id: @user.id,
        title: content[:topic].titleize,
        body: content[:ideas],
        status: 'draft',
        content_type: 'social_media',
        source: 'ai_generated',
        generation_metadata: content
      )
    end
    
    { 
      success: true, 
      action: 'content_generated', 
      generated_count: generated_content.length,
      topics: topics,
      content_ids: Content.where(user_id: @user.id, source: 'ai_generated', created_at: Time.current).pluck(:id)
    }
  end

  # Execute performance analysis task
  def execute_performance_analysis_task(task)
    analysis_depth = task.config['analysis_depth'] || 'basic'
    include_recommendations = task.config['include_recommendations'] != false
    
    # Get performance data
    performance_data = PerformanceMetric.joins(:content)
                                  .where(contents: { user_id: @user.id })
                                  .where('performance_metrics.created_at >= ?', 7.days.ago)
    
    if analysis_depth == 'detailed'
      # More detailed analysis
      detailed_analysis = {
        top_performing_posts: performance_data.order(:engagement_rate).last(5).pluck(:content_id, :engagement_rate),
        engagement_trends: performance_data.group('DATE(created_at)').sum(:engagement_rate),
        platform_breakdown: performance_data.group(:platform).average(:engagement_rate)
      }
    end
    
    # Generate insights
    insights = generate_performance_insights(performance_data, include_recommendations)
    
    # Create analysis report
    analysis_report = AiTaskResult.create!(
      user_id: @user.id,
      task_type: 'performance_analysis',
      result_data: {
        analysis_depth: analysis_depth,
        insights: insights,
        detailed_analysis: detailed_analysis,
        generated_at: Time.current
      },
      summary: insights.join(' ')
    )
    
    { 
      success: true, 
      action: 'analysis_completed', 
      analysis_id: analysis_report.id,
      insights_count: insights.length
    }
  end

  # Execute trends analysis task
  def execute_trends_analysis_task(task)
    include_hashtags = task.config['include_hashtags'] != false
    save_to_drafts = task.config['save_to_drafts'] != false
    
    # Analyze trends
    trends_service = TrendDetectionService.new(@user)
    trends = trends_service.detect_all_trends
    
    # Filter trending content
    trending_topics = trends[:topic_trends].select { |topic| topic[:trend_direction] == 'rising' }
    
    generated_trend_content = []
    trending_topics.first(3).each do |topic|
      # Generate content based on trend
      ai_service = AiChatService.new(@user)
      prompt = "Create a social media post about #{topic[:keyword]} that would appeal to an audience interested in this trending topic."
      
      response = ai_service.generate_response(prompt)
      if response[:success]
        content = {
          topic: topic[:keyword],
          trend_score: topic[:change_percent],
          content: response[:response],
          generated_at: Time.current
        }
        
        # Save to drafts if requested
        if save_to_drafts
          Content.create!(
            user_id: @user.id,
            title: "Trending: #{topic[:keyword]}",
            body: response[:response],
            status: 'draft',
            content_type: 'social_media',
            source: 'trend_based',
            generation_metadata: content
          )
        end
        
        generated_trend_content << content
      end
    end
    
    { 
      success: true, 
      action: 'trends_analyzed', 
      trending_topics: trending_topics.length,
      generated_content: generated_trend_content.length
    }
  end

  # Execute AI insights task
  def execute_ai_insights_task(task)
    insight_types = task.config['insight_types'] || ['audience', 'content']
    
    ai_service = AiChatService.new(@user)
    insights = []
    
    # Generate audience insights
    if insight_types.include?('audience')
      audience_data = get_audience_data
      audience_prompt = "Based on this audience data, provide 3 actionable insights about audience behavior and preferences: #{audience_data}"
      audience_response = ai_service.generate_response(audience_prompt)
      insights << { type: 'audience', insights: audience_response[:response] } if audience_response[:success]
    end
    
    # Generate content insights
    if insight_types.include?('content')
      content_data = get_content_performance_data
      content_prompt = "Based on this content performance data, provide 3 actionable insights about content optimization: #{content_data}"
      content_response = ai_service.generate_response(content_prompt)
      insights << { type: 'content', insights: content_response[:response] } if content_response[:success]
    end
    
    # Generate engagement insights
    if insight_types.include?('engagement')
      engagement_data = get_engagement_data
      engagement_prompt = "Based on this engagement data, provide 3 actionable insights about improving engagement: #{engagement_data}"
      engagement_response = ai_service.generate_response(engagement_prompt)
      insights << { type: 'engagement', insights: engagement_response[:response] } if engagement_response[:success]
    end
    
    # Save insights
    insights_result = AiTaskResult.create!(
      user_id: @user.id,
      task_type: 'ai_insights',
      result_data: {
        insight_types: insight_types,
        insights: insights,
        generated_at: Time.current
      },
      summary: insights.map { |insight| "[#{insight[:type].titleize}] #{insight[:insights]}" }.join(' ')
    )
    
    { 
      success: true, 
      action: 'insights_generated', 
      insights_id: insights_result.id,
      insights_count: insights.length
    }
  end

  # Execute content optimization task
  def execute_content_optimization_task(task)
    optimization_focus = task.config['optimization_focus'] || 'engagement'
    max_content = task.config['max_content'] || 3
    
    # Get content to optimize
    content_to_optimize = @user.contents.published
                           .where('created_at >= ?', 30.days.ago)
                           .order(:created_at)
                           .limit(max_content)
    
    optimized_content = []
    
    content_to_optimize.each do |content|
      # Generate optimization suggestions
      ai_service = AiChatService.new(@user)
      prompt = "Analyze this content and provide 3 specific optimization suggestions to improve #{optimization_focus}: Title: #{content.title}, Body: #{content.body}"
      
      response = ai_service.generate_response(prompt)
      if response[:success]
        optimization = {
          content_id: content.id,
          original_title: content.title,
          original_body: content.body,
          suggestions: response[:response],
          optimized_at: Time.current
        }
        
        optimized_content << optimization
        
        # Store optimization suggestions
        content.update!(
          optimization_suggestions: response[:response],
          last_optimized_at: Time.current
        )
      end
    end
    
    { 
      success: true, 
      action: 'content_optimized', 
      optimized_count: optimized_content.length,
      focus: optimization_focus
    }
  end

  # Execute engagement analysis task
  def execute_engagement_analysis_task(task)
    platforms = task.config['platforms'] || 'all'
    include_predictions = task.config['include_predictions'] != false
    
    # Get engagement data
    engagement_data = get_engagement_analysis_data(platforms)
    
    # Generate predictions if requested
    predictions = []
    if include_predictions
      ai_service = AiChatService.new(@user)
      prediction_prompt = "Based on this engagement data, predict the top 3 areas for improvement and expected outcomes: #{engagement_data}"
      
      response = ai_service.generate_response(prediction_prompt)
      predictions = response[:response] if response[:success]
    end
    
    # Create engagement report
    engagement_report = AiTaskResult.create!(
      user_id: @user.id,
      task_type: 'engagement_analysis',
      result_data: {
        platforms: platforms,
        engagement_data: engagement_data,
        predictions: predictions,
        generated_at: Time.current
      },
      summary: "Engagement analysis completed for #{platforms} platforms"
    )
    
    { 
      success: true, 
      action: 'engagement_analyzed', 
      report_id: engagement_report.id,
      has_predictions: predictions.any?
    }
  end

  # Helper methods for data gathering
  def generate_performance_insights(performance_data, include_recommendations)
    insights = []
    
    if performance_data.any?
      avg_engagement = performance_data.average(:engagement_rate) || 0
      
      if avg_engagement > 5
        insights << "Your average engagement rate of #{avg_engagement.round(1)}% is above industry average. Keep up the great work!"
      else
        insights << "Your average engagement rate of #{avg_engagement.round(1)}% has room for improvement. Consider optimizing your posting times and content."
      end
      
      # Find best performing content type
      best_content_type = performance_data.joins(:content)
                                       .group(:content_type)
                                       .average(:engagement_rate)
                                       .max_by { |_type, engagement| engagement }[0]
      
      if best_content_type
        insights << "#{best_content_type.titleize} content performs best. Consider creating more of this content type."
      end
    end
    
    insights
  end

  def get_audience_data
    # Get audience metrics
    metrics = PerformanceMetric.joins(:content)
                          .where(contents: { user_id: @user.id })
                          .where('performance_metrics.created_at >= ?', 30.days.ago)
    
    {
      total_posts: metrics.count,
      avg_engagement: metrics.average(:engagement_rate)&.round(2) || 0,
      top_platform: metrics.group(:platform).count.max_by { |_platform, count| count }&.first || 'N/A'
    }.to_json
  end

  def get_content_performance_data
    contents = @user.contents.published
                .where('created_at >= ?', 30.days.ago)
                .joins(:performance_metrics)
                .group(:content_type)
                .count
    contents.to_json
  end

  def get_engagement_data
    metrics = PerformanceMetric.joins(:content)
                          .where(contents: { user_id: @user.id })
                          .where('performance_metrics.created_at >= ?', 7.days.ago)
    
    {
      daily_engagement: metrics.group('DATE(created_at)').sum(:engagement_rate),
      platform_breakdown: metrics.group(:platform).average(:engagement_rate)
    }.to_json
  end

  def get_engagement_analysis_data(platforms)
    query = PerformanceMetric.joins(:content)
                       .where(contents: { user_id: @user.id })
                       .where('performance_metrics.created_at >= ?', 14.days.ago)
    
    query = query.where(platform: platforms) if platforms != 'all'
    
    {
      total_interactions: query.sum(:likes + :comments + :shares),
      engagement_trends: query.group('DATE(created_at)').average(:engagement_rate),
      top_performing_posts: query.order(:engagement_rate).last(5).pluck(:content_id, :engagement_rate)
    }
  end
end