# frozen_string_literal: true

class VoiceChatChannel < ApplicationCable::Channel
  def subscribed
    # Use stream_name if provided, otherwise fall back to user-based channel
    stream_name = params[:stream_name] || "voice_chat_#{current_user&.id}"
    stream_from stream_name
    Rails.logger.info "[VoiceChatChannel] Subscribed to stream: #{stream_name}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    Rails.logger.info "[VoiceChatChannel] Unsubscribed"
  end

  def transcribe_and_respond(data)
    audio_data = data['audio']
    conversation_id = data['conversation_id']

    Rails.logger.info "[VoiceChatChannel] transcribe_and_respond called with conversation_id: #{conversation_id}"
  end
end
