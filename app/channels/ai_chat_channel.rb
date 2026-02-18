class AiChatChannel < ApplicationCable::Channel
  def subscribed
    conversation_id = params[:conversation_id]
    stream_from "ai_chat_#{conversation_id}"
  end

  def unsubscribed
    # Clean up any resources
  end
end
