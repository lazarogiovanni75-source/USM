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
    Rails.logger.info "AI Autopilot: Processing voice command: '#{command_text}'"

    # Determine command type based on keywords
    command_type = determine_command_type(command_text)
    Rails.logger.info "AI Autopilot: Determined command type: '#{command_type}'"

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
    elsif text.include?('campaign') || text.include?('new campaign') || text.include?('create campaign')
      'create_campaign'
    elsif text.include?('content') || text.include?('post') || text.include?('generate') || text.include?('create post') || text.include?('write')
      'generate_content'
    elsif text.include?('schedule') || text.include?('post')
      'schedule_post'
    elsif text.include?('analytics') || text.include?('performance') || text.include?('stats') || text.include?('analyze')
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

    confirmation = "✅ Campaign created!\n"\
      "📛 Name: #{campaign.name}\n"\
      "📅 Runs: #{campaign.start_date.strftime('%B %d')} - #{campaign.end_date.strftime('%B %d, %Y')}\n"\
      "💰 Budget: $#{campaign.budget}\n"\
      "💡 Next: Add content or generate posts for this campaign"

    @command.update!(status: 'completed', response_text: confirmation)
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

    confirmation = "✅ Content generated!\n"\
      "📝 Title: #{content.title}\n"\
      "📄 Type: #{content.content_type}\n"\
      "💾 Status: Saved as draft\n"\
      "💡 Next: Review, edit, or schedule this content"

    @command.update!(status: 'completed', response_text: confirmation)
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
      duration: 10
    )

    # Queue video generation job
    GenerateVideoJob.perform_later(video.id, topic)

    confirmation = "🎬 Video generation started!\n"\
      "📹 Topic: #{topic}\n"\
      "⏱ Duration: 10 seconds\n"\
      "🔄 Status: Processing (usually 1-2 mins)\n"\
      "💡 I'll notify you when it's ready!"

    @command.update!(status: 'processing', response_text: confirmation)
    video
  end

  def schedule_post_from_voice(text)
    # Parse scheduling details from voice command
    scheduled_time = Time.current + 1.hour

    # Get user's available content and social account
    latest_content = @command.user.contents.last
    social_account = @command.user.social_accounts.first

    unless latest_content && social_account
      confirmation = "⚠️ Cannot schedule - need content and a connected social account.\n"\
        "💡 Try: 'Generate content' first, then 'schedule post'"
      @command.update!(status: 'completed', response_text: confirmation)
      return nil
    end

    scheduled_post = ScheduledPost.create!(
      content: latest_content,
      social_account: social_account,
      scheduled_at: scheduled_time,
      status: 'scheduled'
    )

    confirmation = "📅 Post scheduled!\n"\
      "🕐 When: #{scheduled_time.strftime('%B %d at %I:%M %p')}\n"\
      "📱 Platform: #{social_account.platform.titleize}\n"\
      "📝 Content: #{latest_content.title}\n"\
      "💡 Next: Add more posts or check analytics later"

    @command.update!(status: 'completed', response_text: confirmation)
    scheduled_post
  end

  def analyze_performance_from_voice(text)
    # Generate performance analysis
    user = @command.user
    total_content = user.contents.count
    total_scheduled = user.scheduled_posts.count
    total_campaigns = user.campaigns.count
    published_posts = user.scheduled_posts.where(status: 'published').count

    analytics_data = {
      total_content: total_content,
      total_scheduled: total_scheduled,
      total_campaigns: total_campaigns,
      published_posts: published_posts
    }

    confirmation = "📊 Your Analytics:\n"\
      "📝 Total Content: #{total_content}\n"\
      "📅 Scheduled: #{total_scheduled}\n"\
      "✅ Published: #{published_posts}\n"\
      "🎯 Campaigns: #{total_campaigns}\n"\
      "💡 Tip: Check the dashboard for detailed metrics!"

    @command.update!(status: 'completed', response_text: confirmation)
    analytics_data
  end

  def general_inquiry_response(text)
    # Use AI to generate helpful response
    response = generate_ai_response(text)

    @command.update!(status: 'completed', response_text: response)
    response
  end

  def generate_content
    # Use LlmService for actual AI content generation
    topic = @content_type || "social media content"
    platform = @platform || "general"

    system_prompt = "You are a professional social media content creator. Generate engaging, platform-specific content that captures attention and drives engagement."

    user_prompt = if @campaign
      "Generate a #{@content_type || 'post'} for #{platform} platform for campaign: #{@campaign.name}. "\
      "Campaign description: #{@campaign.description}. "\
      "Target audience: #{@campaign.target_audience}. "\
      "Make it engaging, include relevant hashtags, and a clear call-to-action."
    else
      "Generate an engaging #{@content_type || 'post'} for #{platform} platform. "\
      "Include relevant hashtags and a clear call-to-action."
    end

    content_text = LlmService.new(
      prompt: user_prompt,
      system: system_prompt,
      temperature: 0.8,
      max_tokens: 500
    ).call_blocking

    content = Content.create!(
      user: @campaign.user,
      campaign: @campaign,
      title: "AI Generated #{@content_type.titleize}",
      body: content_text,
      content_type: @content_type,
      platform: platform,
      status: 'draft'
    )

    content
  rescue => e
    Rails.logger.error "[AiAutopilotService] Content generation failed: #{e.message}"
    # Fallback content
    Content.create!(
      user: @campaign.user,
      campaign: @campaign,
      title: "AI Generated #{@content_type.titleize}",
      body: "AI content generation is temporarily unavailable. Please try again later.",
      content_type: @content_type,
      platform: platform,
      status: 'draft'
    )
  end

  def generate_video
    # Generate video using AI service
    topic = @video_params[:topic] || "social media content"
    duration = @video_params[:duration] || 10

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
    return "social media content" if text.blank?
    
    words = text.split
    # Remove common words and return meaningful phrase
    stop_words = ['a', 'an', 'the', 'generate', 'create', 'make', 'video', 'content', 'post', 'about', 'for', 'to', 'please', 'i', 'want', 'need', 'would', 'like', 'could', 'can', 'help', 'me', 'my', 'with', 'and', 'or', 'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'should', 'could', 'may', 'might', 'must', 'shall', 'can', 'need', 'dare', 'ought', 'used']
    topic_words = words.reject { |w| stop_words.include?(w.downcase) }
    result = topic_words.first(5).join(' ')
    result.blank? ? "social media content" : result
  end

  def generate_ai_response(prompt)
    # Generate AI response using OpenAI or similar
    api_key = ENV.fetch('OPENAI_API_KEY', '') || ENV.fetch('LLM_API_KEY', '')
    
    if api_key.nil? || api_key.empty?
      Rails.logger.error "AI Autopilot: No OpenAI API key available"
      return "I can help you create campaigns, generate content, schedule posts, and more. Try saying something like 'create a campaign' or 'generate a post about summer sale'."
    end

    client = OpenAI::Client.new(
      access_token: api_key,
      uri_base: 'https://api.openai.com/v1'
    )

    response = client.chat(
      parameters: {
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: 'You are an AI assistant for social media management. Help users with their social media strategy, content creation, and campaign management. Keep responses brief and actionable.' },
          { role: 'user', content: prompt }
        ],
        max_tokens: 150
      }
    )

    response.dig('choices', 0, 'message', 'content') || "I'm here to help with your social media needs!"
  rescue StandardError => e
    Rails.logger.error "AI Autopilot response error: #{e.message}"
    "I understood your request. You can ask me to create campaigns, generate content, schedule posts, or analyze performance."
  end
end
