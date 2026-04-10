module Api
  module V1
    class OttoController < ApplicationController
  before_action :authenticate_user!

  def chat
    user_message = params[:message].to_s.strip

    if user_message.blank?
      render json: { error: "Message cannot be blank" }, status: :unprocessable_entity
      return
    end

    # Save the user's message
    current_user.otto_messages.create!(role: "user", content: user_message)

    # Build conversation history (last 20 messages)
    history = current_user.otto_messages.recent.map do |msg|
      { role: msg.role, content: msg.content }
    end

    # Call Anthropic API
    client = Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])

    response = client.messages(
      model: "claude-sonnet-4-20250514",
      max_tokens: 1024,
      system: otto_system_prompt,
      messages: history
    )

    assistant_reply = response.content.first.text

    # Save assistant reply
    current_user.otto_messages.create!(role: "assistant", content: assistant_reply)

    render json: { reply: assistant_reply }

  rescue => e
    Rails.logger.error "Otto-Pilot error: #{e.message}"
    render json: { error: "Otto-Pilot is unavailable right now. Please try again." }, status: :internal_server_error
  end

  def clear
    current_user.otto_messages.destroy_all
    render json: { success: true }
  end

  private

  def otto_system_prompt
    <<~PROMPT
      You are Otto-Pilot, an AI assistant built into Ultimate Social Media — an AI-powered social media automation platform.

      You help users with:
      - Writing social media captions, posts, and content for any platform (Instagram, Facebook, TikTok, LinkedIn, X, Pinterest, Bluesky, Threads, YouTube)
      - Suggesting hashtags, hooks, and content ideas
      - Advising on posting strategies and best times to post
      - Helping with brand voice and tone
      - Answering any general questions the user has
      - Explaining how to use features in the app

      You are friendly, concise, and encouraging. You speak like a knowledgeable social media expert and marketing strategist. Keep responses clear and actionable. When generating content, always provide ready-to-use copy the user can post directly.

      The user's name is #{current_user.name rescue 'there'}.
    PROMPT
  end
    end
  end
end
