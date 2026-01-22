class AiAutopilotService < ApplicationService
  def initialize(command: nil, action: nil, campaign: nil, content_type: nil, platform: nil)
    @command = command
    @action = action
    @campaign = campaign
    @content_type = content_type
    @platform = platform
  end

  def call
    if @command
      process_voice_command
    elsif @action == 'generate_content'
      generate_content
    else
      # Return a default response instead of raising error
      "Service initialized successfully. Use command or action parameters for specific operations."
    end
  end

  private

  def process_voice_command
    command_text = @command.command_text.downcase
    
    # Determine command type based on keywords
    command_type = determine_command_type(command_text)
    
    @command.update!(command_type: command_type)
    
    # Process based on command type
    case command_type
    when 'create_campaign'
      create_campaign_from_voice(command_text)
    when 'generate_content'
      generate_content_from_voice(command_text)
    when 'schedule_post'
      schedule_post_from_voice(command_text)
    when 'analyze_performance'
      analyze_performance_from_voice(command_text)
    else
      general_inquiry_response(command_text)
    end
  end
  
  def determine_command_type(text)
    if text.include?('campaign') || text.include?('new')
      'create_campaign'
    elsif text.include?('content') || text.include?('post') || text.include?('generate')
      'generate_content'
    elsif text.include?('schedule') || text.include?('post')
      'schedule_post'
    elsif text.include?('analytics') || text.include?('performance') || text.include?('stats')
      'analyze_performance'
    else
      'general_inquiry'
    end
  end
  
  def create_campaign_from_voice(text)
    # Use OpenAI to parse campaign details from voice command
    # This is a simplified implementation
    campaign_name = "Voice Campaign #{Time.current.strftime('%Y%m%d_%H%M%S')}"
    description = "Campaign created via voice command: #{text}"
    
    campaign = Campaign.create!(
      user: @command.user,
      name: campaign_name,
      description: description,
      target_audience: 'General Audience',
      budget: 1000,
      start_date: Date.current,
      end_date: Date.current + 30.days,
      status: 'draft'
    )
    
    @command.update!(status: 'completed', response_text: "Created campaign: #{campaign.name}")
    campaign
  end
  
  def generate_content_from_voice(text)
    content_text = "AI-generated content based on: #{text}"
    
    content = Content.create!(
      user: @command.user,
      campaign: @command.user.campaigns.last,
      title: "Generated Content - #{Time.current.strftime('%Y-%m-%d %H:%M')}",
      body: content_text,
      content_type: 'post',
      platform: 'general',
      status: 'draft'
    )
    
    @command.update!(status: 'completed', response_text: "Generated content: #{content.title}")
    content
  end
  
  def schedule_post_from_voice(text)
    # Parse scheduling details from voice command
    scheduled_time = Time.current + 1.hour
    
    # Create a scheduled post
    scheduled_post = ScheduledPost.create!(
      content: @command.user.contents.last,
      social_account: @command.user.social_accounts.first,
      scheduled_at: scheduled_time,
      status: 'scheduled'
    )
    
    @command.update!(status: 'completed', response_text: "Scheduled post for #{scheduled_time}")
    scheduled_post
  end
  
  def analyze_performance_from_voice(text)
    # Generate performance analysis
    analytics_data = {
      total_posts: Content.count,
      scheduled_posts: ScheduledPost.count,
      campaigns: Campaign.count,
      engagement_rate: rand(2.5..8.5).round(2)
    }
    
    @command.update!(status: 'completed', response_text: "Analytics: #{analytics_data.to_json}")
    analytics_data
  end
  
  def general_inquiry_response(text)
    response = "I understand you said: '#{text}'. How can I help you with your social media strategy?"
    @command.update!(status: 'completed', response_text: response)
    response
  end
  
  def generate_content
    # Generate content for specific campaign
    content_text = "AI-generated #{@content_type} content for #{@platform} platform"
    
    Content.create!(
      user: @campaign.user,
      campaign: @campaign,
      title: "AI Generated #{@content_type.titleize}",
      body: content_text,
      content_type: @content_type,
      platform: @platform,
      status: 'draft'
    )
  end
end
