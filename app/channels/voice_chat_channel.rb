# frozen_string_literal: true

class VoiceChatChannel < ApplicationCable::Channel
  def subscribed
    # Use stream_name if provided, otherwise fall back to user-based channel
    @stream_name = params[:stream_name] || "voice_chat_#{current_user&.id}"
    stream_from @stream_name
    
    # Also subscribe to user-level channel for general broadcasts
    # This is important: frontend subscribes to voice_chat_{user_id}
    user_stream = "voice_chat_#{current_user&.id}"
    stream_from user_stream unless @stream_name == user_stream
    
    Rails.logger.info "[VoiceChatChannel] Subscribed to stream: #{@stream_name} and #{user_stream}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    Rails.logger.info "[VoiceChatChannel] Unsubscribed"
  end

  def transcribe_and_respond(data)
    audio_data = data['audio']
    conversation_id = data['conversation_id']
    system_prompt = data['system_prompt']

    Rails.logger.info "[VoiceChatChannel] transcribe_and_respond called with conversation_id: #{conversation_id}"

    return unless audio_data.present? && current_user

    # Get or create conversation
    conversation = if conversation_id.present?
      AiConversation.find_by(id: conversation_id, user: current_user)
    else
      # Create a new conversation if none provided
      AiConversation.create!(
        user: current_user,
        title: "Voice Chat #{Time.current.strftime('%Y-%m-%d %H:%M')}",
        session_type: "voice"
      )
    end

    return unless conversation

    # Get stream name for this conversation (matches backend format: voice_chat_{user_id}_{conversation_id})
    conversation_stream_name = "voice_chat_#{current_user.id}_#{conversation.id}"
    # Also broadcast to user-level channel
    user_stream_name = "voice_chat_#{current_user.id}"

    # Enqueue the voice stream job
    VoiceStreamJob.perform_later(
      stream_name: conversation_stream_name,
      user_stream_name: user_stream_name,
      prompt: audio_data,
      system: system_prompt,
      conversation_id: conversation.id,
      user_id: current_user.id,
      enable_tools: true
    )

    Rails.logger.info "[VoiceChatChannel] VoiceStreamJob enqueued for conversation #{conversation.id}"
    
    # Immediately acknowledge receipt and send conversation_id
    ActionCable.server.broadcast(user_stream_name, {
      type: 'conversation_created',
      conversation_id: conversation.id,
      message: 'Voice processing started'
    })
  rescue => e
    Rails.logger.error "[VoiceChatChannel] Error in transcribe_and_respond: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")

    # Broadcast error to frontend
    ActionCable.server.broadcast("voice_chat_#{current_user&.id}", {
      type: 'error',
      error: "Failed to process voice: #{e.message}"
    })
  end
end
