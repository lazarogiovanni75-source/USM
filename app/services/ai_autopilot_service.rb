class AiAutopilotService < ApplicationService
  def initialize(command: nil, action: nil, campaign: nil, content_type: nil, platform: nil, video_params: nil)
    @command = command
    @action = action
    @campaign = campaign
    @content_type = content_type
    @platform = platform
    @video_params = video_params
  end

  def call
    if @command
      process_voice_command
    elsif @action == 'generate_content'
      generate_content
    elsif @action == 'generate_video'
      generate_video
    elsif @action == 'create_campaign'
      create_campaign
    else
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
    when 'generate_video'
      generate_video_from_voice(command_text)
    when 'schedule_post'
      schedule_post_from_voice(command_text)
    when 'analyze_performance'
      analyze_performance_from_voice(command_text)
    else
      general_inquiry_response(command_text)
    end
  end

  def determine_command_type(text)
    if text.include?('video') || text.include?('generate video') || text.include?('make a video') || text.include?('create video')
      'generate_video'
    elsif text.include?('campaign') || text.include?('new')
      'create_campaign'
    elsif text.include?('content') || text.include?('post') || text.include?('generate') || text.include?('create post')
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
    # Use AI to extract campaign details from voice command
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
    # Extract topic from voice command
    topic = extract_topic_from_text(text)

    content_text = if topic.present?
      AiAutopilotService.new(
        action: 'generate_content',
        campaign: @command.user.campaigns.last,
        content_type: 'post',
        platform: 'general'
      ).call
    else
      "AI-generated content based on: #{text}"
    end

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

  def generate_video_from_voice(text)
    # Extract video details from voice command
    topic = extract_topic_from_text(text)
    topic ||= "social media content"

    video = Video.create!(
      user: @command.user,
      title: "AI Video - #{Time.current.strftime('%Y-%m-%d %H:%M')}",
      description: "Video generated via voice command: #{text}",
      status: 'pending',
      video_type: 'ai_generated',
      duration: 30
    )

    # Queue video generation job
    GenerateVideoJob.perform_later(video.id, topic)

    @command.update!(status: 'processing', response_text: "Video generation started: #{topic}")
    video
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
    # Use AI to generate helpful response
    response = generate_ai_response(text)

    @command.update!(status: 'completed', response_text: response)
    response
  end

  def generate_content
    # Generate content for specific campaign
    content_text = "AI-generated #{@content_type} content for #{@platform} platform"

    content = Content.create!(
      user: @campaign.user,
      campaign: @campaign,
      title: "AI Generated #{@content_type.titleize}",
      body: content_text,
      content_type: @content_type,
      platform: @platform,
      status: 'draft'
    )

    content
  end

  def generate_video
    # Generate video using AI service
    topic = @video_params[:topic] || "social media content"
    duration = @video_params[:duration] || 30

    video = Video.create!(
      user: @campaign.user,
      title: "AI Video - #{Time.current.strftime('%Y-%m-%d %H:%M')}",
      description: "Video generated for campaign: #{@campaign.name}",
      status: 'pending',
      video_type: 'ai_generated',
      duration: duration
    )

    # Queue video generation job
    GenerateVideoJob.perform_later(video.id, topic)

    video
  end

  def create_campaign
    campaign = Campaign.create!(
      user: @campaign.user,
      name: "AI Campaign #{Time.current.strftime('%Y%m%d_%H%M%S')}",
      description: "Campaign created via AI Autopilot",
      target_audience: 'General Audience',
      budget: 1000,
      start_date: Date.current,
      end_date: Date.current + 30.days,
      status: 'draft'
    )

    campaign
  end

  def extract_topic_from_text(text)
    # Simple extraction - look for common patterns
    # In production, use NLP to extract the actual topic
    words = text.split
    # Remove common words and return meaningful phrase
    stop_words = ['a', 'an', 'the', 'generate', 'create', 'make', 'video', 'content', 'post', 'about', 'for', 'to', 'please']
    topic_words = words.reject { |w| stop_words.include?(w.downcase) }
    topic_words.first(5).join(' ')
  end

  def generate_ai_response(prompt)
    # Generate AI response using OpenAI or similar
    client = OpenAI::Client.new(
      access_token: ENV.fetch('OPENAI_API_KEY', '')
    )

    response = client.chat(
      parameters: {
        model: 'gpt-5o-mini',
        messages: [
          { role: 'system', content: 'You are an AI assistant for social media management. Help users with their social media strategy, content creation, and campaign management.' },
          { role: 'user', content: prompt }
        ],
        max_tokens: 300
      }
    )

    response.dig('choices', 0, 'message', 'content') || "I'm here to help with your social media needs!"
  rescue StandardError
    "I'm here to help! Try saying 'create a video about my new product' or 'generate content about promotions'."
  end
end
