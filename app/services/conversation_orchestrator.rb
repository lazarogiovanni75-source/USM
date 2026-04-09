# frozen_string_literal: true

# ConversationOrchestrator - Text-only AI chat with actionable suggestions
class ConversationOrchestrator < ApplicationService
  MAX_HISTORY_MESSAGES = 15
  CLAUDE_MODEL = "claude-sonnet-4-6"
  CHAT_TEMPERATURE = 0.8
  CHAT_MAX_TOKENS = 4000

  attr_reader :user, :conversation, :content, :modality, :stream_channel

  def initialize(user:, conversation_id:, content:, modality: "text", stream_channel: nil)
    @user = user
    @conversation = find_or_create_conversation(conversation_id)
    @content = content
    @modality = modality
    @stream_channel = stream_channel
    @assistant_response = ""
    @suggested_actions = []
  end

  def self.process_message(**args)
    new(**args).call
  end

  def call
    Rails.logger.info "[ConversationOrchestrator] === START ==="
    Rails.logger.info "[ConversationOrchestrator] user: #{user&.id} (#{user&.email})"
    Rails.logger.info "[ConversationOrchestrator] conversation: #{conversation.id rescue 'nil'}"

    # Save user message
    conversation.ai_messages.create!(
      role: 'user',
      content: content,
      message_type: 'text',
      metadata: { modality: modality }
    )

    # Detect user intent
    intent = detect_intent
    Rails.logger.info "[ConversationOrchestrator] Detected intent: #{intent}"

    # Handle based on intent
    case intent
    when :image
      handle_image_intent
    when :video
      handle_video_intent
    when :campaign
      handle_campaign_intent
    when :content
      handle_content_intent
    else
      handle_general_chat
    end

    conversation.touch
    @assistant_response ||= ""

    # Save assistant message with action metadata
    conversation.ai_messages.create!(
      role: 'assistant',
      content: @assistant_response,
      message_type: 'text',
      metadata: {
        model: CLAUDE_MODEL,
        suggested_actions: @suggested_actions
      }
    )

    {
      conversation_id: conversation.id,
      response: @assistant_response,
      suggested_actions: @suggested_actions
    }
  rescue => e
    Rails.logger.error "[ConversationOrchestrator] Error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")

    error_message = "I apologize, but I encountered an error processing your message. [#{e.class}]"
    begin
      conversation.ai_messages.create!(
        role: 'assistant',
        content: error_message,
        message_type: 'text'
      )
    rescue => save_error
      Rails.logger.error "[ConversationOrchestrator] Failed to save error: #{save_error.message}"
    end
    broadcast_error(error_message) if stream_channel

    {
      conversation_id: conversation&.id,
      response: error_message,
      suggested_actions: []
    }
  end

  private

  def broadcast_content(delta)
    return unless stream_channel
    ActionCable.server.broadcast(stream_channel, {
      type: 'chunk',
      chunk: delta
    })
  end

  def broadcast_error(message)
    return unless stream_channel
    ActionCable.server.broadcast(stream_channel, {
      type: 'error',
      error: message
    })
  end

  def find_or_create_conversation(conversation_id)
    if conversation_id.present?
      conv = user.ai_conversations.find_by(id: conversation_id)
      return conv if conv
    end

    AiConversation.create!(
      user: user,
      title: "Chat #{Time.current.strftime('%b %d, %I:%M %p')}",
      session_type: 'chat',
      metadata: { created_via: modality }
    )
  end

  def detect_intent
    content_lower = content.downcase

    return :image if content_lower.include?('generate image') || content_lower.include?('create image') || content_lower.include?('image for')
    return :video if content_lower.include?('generate video') || content_lower.include?('create video') || content_lower.include?('video for')
    return :campaign if content_lower.include?('campaign') || content_lower.include?('marketing plan')
    return :content if content_lower.include?('post') || content_lower.include?('caption') || content_lower.include?('content')

    :general
  end

  def handle_image_intent
    # Extract the actual image concept from user request
    image_prompt = extract_image_prompt(content)

    # Get AI to generate a good prompt for image generation
    image_prompt_response = LlmService.call_blocking(
      prompt: "Create a detailed, effective image generation prompt for: #{image_prompt}. Return ONLY the prompt text, nothing else. Make it detailed and specific for AI image generation.",
      system: "You are an expert at creating prompts for AI image generation. Be specific about style, lighting, composition, and mood.",
      user: user,
      max_tokens: 500
    )

    @suggested_actions = [
      {
        type: 'generate_image',
        label: 'Generate Image',
        icon: 'image',
        data: { prompt: image_prompt_response.strip }
      }
    ]

    @assistant_response = "I can help you create an image! Here's a prompt you can use:\n\n**#{image_prompt_response.strip}**\n\nYou can copy this prompt and use it in the Image Generator, or click the button below to generate it automatically."
  end

  def handle_video_intent
    # Extract the video concept
    video_prompt = extract_video_prompt(content)

    video_prompt_response = LlmService.call_blocking(
      prompt: "Create a detailed, effective video generation prompt for: #{video_prompt}. Return ONLY the prompt text, nothing else.",
      system: "You are an expert at creating prompts for AI video generation. Focus on motion, scenes, and visual storytelling.",
      user: user,
      max_tokens: 500
    )

    @suggested_actions = [
      {
        type: 'generate_video',
        label: 'Generate Video',
        icon: 'video',
        data: { prompt: video_prompt_response.strip }
      }
    ]

    @assistant_response = "Here's a video generation prompt based on your request:\n\n**#{video_prompt_response.strip}**\n\nClick below to generate this video automatically, or copy the prompt for later."
  end

  def handle_campaign_intent
    campaign_name = extract_campaign_name(content)

    @suggested_actions = [
      {
        type: 'create_campaign',
        label: 'Create Campaign',
        icon: 'megaphone',
        data: { name: campaign_name }
      }
    ]

    @assistant_response = "I can help you build a campaign for: **#{campaign_name}**\n\nI'll suggest some ideas:\n\n#{generate_campaign_suggestions}\n\nClick 'Create Campaign' to start building it, or tell me more about what you're looking for!"
  end

  def handle_content_intent
    platform = detect_platform(content)

    @suggested_actions = [
      {
        type: 'generate_content',
        label: 'Generate Content',
        icon: 'file-text',
        data: { platform: platform, topic: content }
      }
    ]

    @assistant_response = "I can help you create content! Based on your request, I'd suggest:\n\n#{generate_content_suggestions}\n\nClick 'Generate Content' to create this automatically."
  end

  def handle_general_chat
    # Standard chat with AI - no special actions
    @suggested_actions = []

    system_prompt = build_system_prompt

    @assistant_response = LlmService.call_blocking(
      prompt: content,
      system: system_prompt,
      user: user,
      max_tokens: CHAT_MAX_TOKENS
    )

    Rails.logger.info "[ConversationOrchestrator] General chat response complete - #{@assistant_response.length} chars"
  end

  def build_system_prompt
    base = begin
      SiteSetting.ai_system_prompt
    rescue
      "You are a helpful AI assistant for a social media marketing platform."
    end

    <<~PROMPT
      #{base}

      You are helping the user with their social media marketing tasks.
      Be conversational, helpful, and concise. When appropriate, suggest
      specific actions they can take (generating images, videos, content, campaigns).
      Format suggestions clearly so they're easy to act on.
    PROMPT
  end

  def extract_image_prompt(text)
    # Extract the core concept the user wants an image of
    text.gsub(/generate|create|make|image|picture|photo|for me/i, '').strip
  end

  def extract_video_prompt(text)
    text.gsub(/generate|create|make|video|for me/i, '').strip
  end

  def extract_campaign_name(text)
    name = text.gsub(/create|build|start|campaign|marketing/i, '').strip
    name.presence || "My Campaign"
  end

  def detect_platform(text)
    text_lower = text.downcase
    return 'instagram' if text_lower.include?('instagram')
    return 'facebook' if text_lower.include?('facebook')
    return 'tiktok' if text_lower.include?('tiktok')
    return 'twitter' if text_lower.include?('twitter')
    return 'linkedin' if text_lower.include?('linkedin')
    'general'
  end

  def generate_campaign_suggestions
    <<~SUGGESTIONS
      1. **7-Day Product Launch** - Build buzz before your launch
      2. **Brand Awareness** - Get your name out there
      3. **Holiday Sale** - Seasonal promotion campaign
    SUGGESTIONS
  end

  def generate_content_suggestions
    <<~SUGGESTIONS
      • A catchy headline
      • 2-3 variations of copy
      • Relevant hashtags
      • Best posting times
    SUGGESTIONS
  end
end
