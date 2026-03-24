class AiChatController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @conversations = current_user.ai_conversations.order(updated_at: :desc).limit(10)
    @current_conversation = @conversations.first || current_user.ai_conversations.create!(
      title: "New Chat #{Time.current.strftime('%b %d, %I:%M %p')}",
      session_type: 'chat',
      metadata: {}
    )
    @messages = @current_conversation.ai_messages.order(created_at: :desc)
    
    # Handle voice_message param from Pilot redirect
    @voice_message = params[:voice_message].presence
    if @voice_message
      Rails.logger.info "[AiChat] Voice message from URL: #{@voice_message[0..50]}"
    end
  end
  
  def show
    @conversations = current_user.ai_conversations.order(updated_at: :desc).limit(10)
    @conversation = current_user.ai_conversations.find(params[:id])
    @messages = @conversation.ai_messages.order(created_at: :desc)
    @current_conversation = @conversation
  end
  
  def create
    @conversation = current_user.ai_conversations.create!(
      title: "Chat #{Time.current.strftime('%b %d, %I:%M %p')}",
      session_type: 'chat',
      metadata: { created_via: 'web' }
    )
    
    redirect_to ai_chat_path(@conversation)
  end
  
  # Legacy endpoint - now uses ConversationOrchestrator
  def send_message
    conversation_id = params[:conversation_id]
    message_content = params[:message]
    
    # Use ConversationOrchestrator for consistent message handling
    # It will create a new conversation if conversation_id is nil
    result = ConversationOrchestrator.process_message(
      user: current_user,
      conversation_id: conversation_id,
      content: message_content,
      modality: "text"
    )
    
    # Get the conversation from result
    @conversation = current_user.ai_conversations.find(result[:conversation_id])
    @messages = @conversation.ai_messages.order(created_at: :desc)
    
    # Return Turbo Stream response for frontend updates
    render 'send_message'
  end
  
  def toggle_voice
    voice_setting = current_user.voice_settings.first_or_initialize
    voice_setting.enabled = !voice_setting.enabled
    voice_setting.save!
    
    redirect_back(fallback_location: ai_chat_index_path)
  end
end