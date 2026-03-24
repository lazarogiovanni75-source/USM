# Content Templates Service
class ContentTemplateService
  def initialize(user = nil)
    @user = user
  end
  
  def create_from_content(content)
    template = ContentTemplate.new(
      user_id: @user&.id,
      name: "Template from #{content.title}",
      description: "Created from content: #{content.title}",
      template_content: "#{content.title}\n\n#{content.body}",
      template_type: :social_post,
      category: :marketing,
      platform: :general
    )
    
    if template.save
      # Extract variables automatically
      variables = extract_variables_from_content(content)
      variables.each do |var_name|
        template.content_template_variables.create!(
          variable_name: var_name,
          variable_type: guess_variable_type(var_name),
          default_value: '',
          placeholder_text: var_name.humanize
        )
      end
      
      template
    else
      template
    end
  end
  
  def process_template_with_suggestions(template, base_variables = {})
    # Get suggested variables based on template type
    suggestions = get_variable_suggestions(template.template_type, template.category)
    
    # Merge with provided variables
    final_variables = suggestions.merge(base_variables)
    
    processed_content = template.process_variables(final_variables)
    
    {
      content: processed_content,
      variables_used: final_variables,
      suggestions_applied: suggestions.keys - base_variables.keys
    }
  end
  
  def get_template_analytics(template_id, days = 30)
    template = ContentTemplate.find(template_id)
    start_date = days.days.ago.beginning_of_day
    end_date = Time.current.end_of_day
    
    contents_using_template = @user.contents.where(template_id: template_id)
                                    .where('created_at >= ?', start_date)
    
    {
      template: template,
      total_usage: contents_using_template.count,
      usage_trend: get_usage_trend(contents_using_template, days),
      platform_breakdown: get_platform_breakdown(contents_using_template),
      performance_metrics: get_performance_metrics(contents_using_template)
    }
  end
  
  def optimize_template_variables(template)
    # Analyze successful posts using this template
    successful_contents = @user.contents.joins(:performance_metrics)
                              .where(template_id: template.id)
                              .where('performance_metrics.likes > ?', 100)
    
    return unless successful_contents.any?
    
    # Extract patterns from high-performing content
    patterns = analyze_content_patterns(successful_contents)
    
    # Update variable suggestions based on patterns
    patterns.each do |pattern_type, values|
      variable = template.content_template_variables.find_by(variable_name: pattern_type)
      next unless variable
      
      # Update validation rules or default suggestions
      validation_rules = variable.validation_rules || {}
      validation_rules[:suggestions] = values.first(5) # Top 5 suggestions
      variable.update!(validation_rules: validation_rules)
    end
  end
  
  def get_templates_for_platform(platform)
    ContentTemplate.for_platform(platform).public_templates.limit(10)
  end
  
  def get_trending_templates(category = nil, platform = nil)
    templates = ContentTemplate.public_templates.order(usage_count: :desc)
    
    templates = templates.by_category(category) if category.present?
    templates = templates.for_platform(platform) if platform.present?
    
    templates.limit(20)
  end
  
  private
  
  def extract_variables_from_content(content)
    # Simple variable extraction based on common patterns
    variables = []
    
    # Extract hashtags
    content.body.scan(/#\w+/).each do |hashtag|
      variables << "hashtag_#{variables.count + 1}"
    end
    
    # Extract mentions
    content.body.scan(/@\w+/).each do |mention|
      variables << "mention_#{variables.count + 1}"
    end
    
    # Extract numbers/prices
    content.body.scan(/\$[\d,]+|\d+%/).each do |number|
      variables << "number_#{variables.count + 1}"
    end
    
    variables.uniq
  end
  
  def guess_variable_type(var_name)
    case var_name.downcase
    when /email/
      :email
    when /url|link/
      :url
    when /date|time/
      :date
    when /number|price/
      :number
    else
      :text
    end
  end
  
  def get_variable_suggestions(template_type, category)
    # Return default suggestions based on template type and category
    suggestions = {}
    
    case template_type.to_sym
    when :social_post
      suggestions.merge!(
        hashtag_1: '#marketing',
        hashtag_2: '#social',
        cta: 'Learn more at our website!',
        audience: 'our community'
      )
    when :blog_post
      suggestions.merge!(
        author_name: 'Author Name',
        reading_time: '5 min read',
        summary: 'Brief summary of the article'
      )
    end
    
    suggestions
  end
  
  def get_usage_trend(contents, days)
    trend = []
    
    days.times do |i|
      date = (Time.current - i.days).beginning_of_day
      count = contents.where('DATE(created_at) = ?', date).count
      trend << { date: date.strftime('%Y-%m-%d'), count: count }
    end
    
    trend.reverse
  end
  
  def get_platform_breakdown(contents)
    contents.joins(:scheduled_posts)
            .group('scheduled_posts.platform')
            .count
            .transform_keys(&:capitalize)
  end
  
  def get_performance_metrics(contents)
    # This would integrate with actual performance metrics
    {
      avg_likes: 150,
      avg_shares: 25,
      avg_comments: 45,
      avg_engagement_rate: 0.08
    }
  end
  
  def analyze_content_patterns(contents)
    # Analyze patterns in successful content
    patterns = {}
    
    contents.each do |content|
      # Extract hashtags from successful content
      hashtags = content.body.scan(/#\w+/)
      hashtags.each do |hashtag|
        patterns["hashtag_1"] ||= []
        patterns["hashtag_1"] << hashtag unless patterns["hashtag_1"].include?(hashtag)
      end
      
      # Extract CTAs
      cta_matches = content.body.scan(/(learn more|sign up|buy now|get started|click here)/i)
      cta_matches.flatten.each do |cta|
        patterns["cta"] ||= []
        patterns["cta"] << cta.capitalize
      end
    end
    
    patterns
  end
end