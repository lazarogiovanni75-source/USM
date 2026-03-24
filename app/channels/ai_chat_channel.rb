class AiChatChannel < ApplicationCable::Channel
  def subscribed
    conversation_id = params[:conversation_id]
    stream_from "ai_chat_#{conversation_id}"
    Rails.logger.info "[AiChatChannel] Subscribed to ai_chat_#{conversation_id}"
  end

  def unsubscribed
    Rails.logger.info "[AiChatChannel] Unsubscribed from conversation"
  end

  # Handle incoming chat messages
  def send_message(data)
    conversation_id = data['conversation_id']
    message_content = data['message']
    
    Rails.logger.info "[AiChatChannel] Received message - conversation: #{conversation_id}"
    
    # Process message with streaming via ConversationOrchestrator
    ConversationOrchestrator.process_message(
      user: current_user,
      conversation_id: conversation_id,
      content: message_content,
      modality: "text",
      stream_channel: "ai_chat_#{conversation_id}"
    )
  rescue => e
    Rails.logger.error "[AiChatChannel] Error: #{e.message}"
    transmit({ type: 'error', error: e.message })
  end
end
