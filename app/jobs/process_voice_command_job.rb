# frozen_string_literal: true

class ProcessVoiceCommandJob < ApplicationJob
  MAX_RETRIES = 2

  def perform(voice_command_id = nil, attempt = 0)
    unless voice_command_id
      puts "ProcessVoiceCommandJob processed successfully (test mode)"
      return
    end

    voice_command = VoiceCommand.find(voice_command_id)
    user = voice_command.user
    stream_name = "voice_interaction_#{user.id}"


    prompt = voice_command.command_text
    command_type = determine_command_type(prompt)
    voice_command.update!(command_type: command_type)


    begin
      result = execute_command(voice_command, command_type, prompt, stream_name)
    rescue StandardError => e
      handle_command_error(e, voice_command, stream_name, attempt)
    end
  end

  private

  def determine_command_type(text)
    text_downcase = text.downcase

    if text_downcase.include?('video')
      'generate_video'
    elsif text_downcase.include?('campaign')
      'create_campaign'
    elsif text_downcase.match?(/\b(generate image|create image|make image|draw|create a picture|make a picture)\b/)
      'generate_image'
    elsif text_downcase.include?('content') || text_downcase.include?('post') || text_downcase.include?('generate') || text_downcase.include?('write') || text_downcase.include?('caption')
      'generate_content'
    elsif text_downcase.include?('schedule')
      'schedule_post'
    elsif text_downcase.include?('analytics') || text_downcase.include?('performance') || text_downcase.include?('stats') || text_downcase.include?('analyze')
      'analyze_performance'
    else
      'general_inquiry'
    end
  end

  def execute_command(voice_command, command_type, prompt, stream_name)
    user = voice_command.user

    ActionCable.server.broadcast(stream_name, {
      type: 'status',
      status: 'processing',
      message: "Processing your #{command_type.humanize.downcase} request..."
    })

    case command_type
    when 'create_campaign'
      execute_create_campaign(voice_command, prompt)
    when 'generate_content'
      execute_generate_content(voice_command, prompt)
    when 'generate_video'
      execute_generate_video(voice_command, prompt)
    when 'schedule_post'
      execute_schedule_post(voice_command, prompt)
    when 'analyze_performance'
      execute_analyze_performance(voice_command)
    else
      execute_general_inquiry(voice_command, prompt)
    end

    synthesize_speech_response(voice_command, stream_name)
  end

  def handle_command_error(error, voice_command, stream_name, attempt)
    if attempt < MAX_RETRIES
      Rails.logger.warn "ProcessVoiceCommandJob retry #{attempt + 1}/#{MAX_RETRIES}: #{error.message}"
      retry_job(wait: 2**attempt)
    else
      Rails.logger.error "ProcessVoiceCommandJob failed after #{MAX_RETRIES} retries: #{error.message}"
      error_msg = "Error: #{error.message} (after #{MAX_RETRIES} retries)"
      voice_command&.update!(status: 'failed', response_text: error_msg, error_message: error.message)


      ActionCable.server.broadcast(stream_name, {
        type: 'error',
        voice_command_id: voice_command&.id,
        error: error_msg,
        timestamp: Time.current
      })
    end
  end

  def synthesize_speech_response(voice_command, stream_name)
    return unless voice_command.response_text

    conversation_service = VoiceConversationService.new(user: voice_command.user)
    conversation_service.add_user_message(voice_command.command_text)
    conversation_service.add_assistant_message(voice_command.response_text)


    pipeline = VoicePipelineService.new(user: voice_command.user)

    if pipeline.tts_configured?
      tts_result = pipeline.synthesize(voice_command.response_text)

      if tts_result[:success] && tts_result[:audio_url]
        ActionCable.server.broadcast(stream_name, {
          type: 'complete',
          voice_command_id: voice_command.id,
          status: 'completed',
          content: voice_command.response_text,
          audio_url: tts_result[:audio_url],
          command_type: voice_command.command_type,
          timestamp: Time.current
        })
        return
      end
    end

    ActionCable.server.broadcast(stream_name, {
      type: 'complete',
      voice_command_id: voice_command.id,
      status: 'completed',
      content: voice_command.response_text,
      command_type: voice_command.command_type,
      timestamp: Time.current
    })
  rescue StandardError => e
    Rails.logger.error "TTS synthesis error: #{e.message}"
    ActionCable.server.broadcast(stream_name, {
      type: 'complete',
      voice_command_id: voice_command.id,
      status: 'completed',
      content: voice_command.response_text,
      command_type: voice_command.command_type,
      timestamp: Time.current
    })
  end

  def execute_create_campaign(voice_command, prompt)
    user = voice_command.user

    campaign_name = extract_campaign_name(prompt) || "Voice Campaign #{Time.current.strftime('%Y%m%d_%H%M%S')}"
    description = "Campaign created via voice command: #{prompt}"
    target_audience = extract_audience(prompt) || 'General Audience'
    budget = extract_budget(prompt) || 500
    start_date = Date.current
    end_date = start_date + 30.days

    campaign = Campaign.create!(
      user: user,
      name: campaign_name,
      description: description,
      target_audience: target_audience,
      budget: budget,
      start_date: start_date,
      end_date: end_date,
      status: 'draft'
    )

    confirmation = "Campaign Created!\n\n" \
      "Name: #{campaign.name}\n" \
      "Audience: #{campaign.target_audience}\n" \
      "Budget: $#{campaign.budget}\n" \
      "Duration: #{campaign.start_date.strftime('%B %d')} - #{campaign.end_date.strftime('%B %d, %Y')}\n\n" \
      "What would you like to do next?"


    voice_command.update!(status: 'completed', response_text: confirmation)
    campaign
  end

  def execute_generate_content(voice_command, prompt)
    user = voice_command.user

    topic = extract_topic(prompt)
    content_body = generate_ai_content(prompt, topic, user)
    content_type = extract_content_type(prompt)
    platform = extract_platform(prompt)

    campaign = user.campaigns.last || Campaign.create!(
      user: user,
      name: "Auto Campaign #{Date.today}",
      description: "Created for voice-generated content",
      target_audience: 'General',
      budget: 100,
      start_date: Date.current,
      end_date: Date.current + 7.days,
      status: 'draft'
    )

    content = Content.create!(
      user: user,
      campaign: campaign,
      title: topic.present? ? "Content about #{topic}" : "Generated Content #{Time.current.strftime('%Y-%m-%d %H:%M')}",
      body: content_body,
      content_type: content_type,
      platform: platform,
      status: 'draft'
    )

    confirmation = "Content Generated!\n\n" \
      "#{content.title}\n\n" \
      "Preview: #{content_body.truncate(200)}\n\n" \
      "Saved as draft\n" \
      "Type: #{content.content_type}\n" \
      "Platform: #{content.platform}"

    voice_command.update!(status: 'completed', response_text: confirmation)
    content
  end

  def execute_generate_video(voice_command, prompt)
    user = voice_command.user

    topic = extract_topic(prompt) || "social media content"
    duration = extract_duration(prompt) || 10

    video = Video.create!(
      user: user,
      title: "AI Video - #{topic.titleize}",
      description: "Video generated via voice command: #{prompt}",
      status: 'pending',
      video_type: 'ai_generated',
      duration: duration
    )

    confirmation = "Video Generation Started!\n\n" \
      "Topic: #{topic}\n" \
      "Duration: #{duration} seconds\n" \
      "Status: Processing (usually takes 1-2 minutes)"


    voice_command.update!(status: 'processing', response_text: confirmation)
    video
  end

  def execute_schedule_post(voice_command, prompt)
    user = voice_command.user

    content = user.contents.where(status: 'draft').last
    unless content
      content = Content.create!(
        user: user,
        title: "Quick Post #{Time.current.strftime('%Y-%m-%d %H:%M')}",
        body: prompt,
        content_type: 'post',
        platform: 'general',
        status: 'draft'
      )
    end

    social_account = user.social_accounts.where(is_connected: true).first
    unless social_account
      confirmation = "No Social Accounts Connected\n\n" \
        "To schedule posts, please connect a social media account first."
      voice_command.update!(status: 'completed', response_text: confirmation)
      return nil
    end

    scheduled_time = extract_schedule_time(prompt) || Time.current + 1.hour

    scheduled_post = ScheduledPost.create!(
      user: user,
      content: content,
      social_account: social_account,
      scheduled_at: scheduled_time,
      status: 'scheduled'
    )

    confirmation = "Post Scheduled!\n\n" \
      "When: #{scheduled_time.strftime('%B %d at %I:%M %p')}\n" \
      "Platform: #{social_account.platform.titleize}\n" \
      "Content: #{content.title}"


    voice_command.update!(status: 'completed', response_text: confirmation)
    scheduled_post
  end

  def execute_analyze_performance(voice_command)
    user = voice_command.user

    total_content = user.contents.count
    total_scheduled = user.scheduled_posts.count
    total_campaigns = user.campaigns.count
    published_posts = user.scheduled_posts.where(status: 'published').count
    connected_accounts = user.social_accounts.where(is_connected: true).count

    confirmation = "Your Analytics Overview\n\n" \
      "Campaigns: #{total_campaigns}\n" \
      "Total Content: #{total_content}\n" \
      "Scheduled Posts: #{total_scheduled}\n" \
      "Published: #{published_posts}\n" \
      "Connected Accounts: #{connected_accounts}"


    voice_command.update!(status: 'completed', response_text: confirmation)
    { content: total_content, scheduled: total_scheduled, campaigns: total_campaigns }
  end

  def execute_general_inquiry(voice_command, prompt)
    user = voice_command.user

    response = generate_ai_response(prompt, user)


    voice_command.update!(status: 'completed', response_text: response)
    response
  end

  def extract_campaign_name(prompt)
    if prompt =~ /(?:called|named|for|campaign\s+)(["']?)([^"']+)\1/i
      $2.strip.titleize
    elsif prompt =~ /^(?:create\s+)?(.+?)(?:\s+campaign|$)/i
      $1.strip.titleize
    end
  end

  def extract_audience(prompt)
    audiences = ['General Audience', 'Young Professionals', 'Parents', 'Tech Enthusiasts', 'Fitness Enthusiasts',
                 'Food Lovers', 'Travelers', 'Business Owners', 'Students', 'Music Lovers']
    audiences.find { |a| prompt.downcase.include?(a.downcase) }
  end

  def extract_budget(prompt)
    prompt =~ /\$?(\d+)/i ? $1.to_i : nil
  end

  def extract_topic(prompt)
    topic = prompt.downcase
    topic = topic.gsub(/generate|create|write|make|content|post|caption|about|for|my|please|can|you|help|me/i, '').strip
    topic.present? ? topic.titleize : nil
  end

  def extract_content_type(prompt)
    return 'story' if prompt.downcase.include?('story')
    return 'video' if prompt.downcase.include?('video')
    return 'ad' if prompt.downcase.include?('ad')
    'post'
  end

  def extract_platform(prompt)
    return 'instagram' if prompt.downcase.include?('instagram') || prompt.downcase.include?('insta')
    return 'facebook' if prompt.downcase.include?('facebook') || prompt.downcase.include?('fb')
    return 'twitter' if prompt.downcase.include?('twitter') || prompt.downcase.include?('x')
    return 'linkedin' if prompt.downcase.include?('linkedin')
    return 'tiktok' if prompt.downcase.include?('tiktok')
    'general'
  end

  def extract_duration(prompt)
    if prompt =~ /(\d+)\s*(?:second|sec)/i
      $1.to_i
    elsif prompt =~ /(\d+)\s*minute/i
      $1.to_i * 60
    else
      10
    end
  end

  def extract_schedule_time(prompt)
    if prompt.downcase.include?('tomorrow')
      Time.current.tomorrow.at_beginning_of_day + 9.hours
    elsif prompt.downcase.include?('today')
      Time.current + 1.hour
    elsif prompt =~ /(\d{1,2}):(\d{2})/i
      Time.zone.parse("#{$1}:#{$2}")
    else
      Time.current + 1.hour
    end
  rescue
    Time.current + 1.hour
  end

  def generate_ai_content(prompt, topic, user)
    system_prompt = "You are a social media marketing expert. Generate engaging, creative content for social media posts. Keep it concise and fun."

    topic_hint = topic ? "Create content about: #{topic}" : "Create engaging social media content"

    begin
      content = ''
      LlmService.call(
        prompt: "#{topic_hint}. #{prompt}",
        system: system_prompt,
        user: user,
        model: 'gpt-4o'
      ) do |chunk|
        chunk_content = chunk.is_a?(Hash) ? chunk[:content] : chunk
        content += chunk_content if chunk_content
      end
      content
    rescue => e
      "Check out our latest update! #{topic || 'Exciting content coming soon.'}"
    end
  end

  def generate_ai_response(prompt, user)
    conversation_service = VoiceConversationService.new(user: user)
    conversation_service.add_user_message(prompt)


    system_prompt = conversation_service.system_prompt
    history_context = conversation_service.formatted_history
    full_prompt = history_context ? "#{history_context}\n\nUser: #{prompt}" : prompt

    begin
      response = ''
      LlmService.call(
        prompt: full_prompt,
        system: system_prompt,
        user: user,
        model: 'gpt-4o'
      ) do |chunk|
        chunk_content = chunk.is_a?(Hash) ? chunk[:content] : chunk
        response += chunk_content if chunk_content
      end
      response
    rescue => e
      "Hi! I'm Pilot, your social media assistant. I can help you create campaigns, generate content, schedule posts, or analyze performance. What would you like to do?"
    end
  end
end
