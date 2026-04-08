class AiChatController < ApplicationController
  before_action :authenticate_user!
  
  # Dedicated action for creating new conversations without message processing
  def new
    @conversation = current_user.ai_conversations.create!(
      title: "Chat #{Time.current.strftime('%b %d, %I:%M %p')}",
      session_type: 'chat',
      metadata: { created_via: 'web' }
    )
    
    redirect_to ai_chat_path(@conversation)
  rescue => e
    Rails.logger.error "[AiChat#new] Error creating conversation: #{e.message}"
    redirect_to ai_chat_index_path, alert: 'Failed to create new chat'
  end
  
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
    message_content = params[:message]
    
    Rails.logger.info "[AiChat#create] message_present=#{message_content.present?}, length=#{message_content&.length || 0}"
    
    # If message is provided, create conversation and process message
    if message_content.present?
      @conversation = current_user.ai_conversations.create!(
        title: "Chat #{Time.current.strftime('%b %d, %I:%M %p')}",
        session_type: 'chat',
        metadata: { created_via: 'web' }
      )
      
      # Process the message using ConversationOrchestrator
      begin
        result = ConversationOrchestrator.process_message(
          user: current_user,
          conversation_id: @conversation.id,
          content: message_content,
          modality: "text"
        )
        
        @messages = @conversation.ai_messages.order(created_at: :desc)
        render 'send_message' and return
      rescue => e
        Rails.logger.error "[AiChat] Error processing message in create: #{e.message}"
        @messages = @conversation.ai_messages.order(created_at: :desc)
        render 'send_message' and return
      end
    else
      # No message, just create conversation and redirect
      @conversation = current_user.ai_conversations.create!(
        title: "Chat #{Time.current.strftime('%b %d, %I:%M %p')}",
        session_type: 'chat',
        metadata: { created_via: 'web' }
      )
      
      redirect_to ai_chat_path(@conversation)
    end
  end
  
  # Legacy endpoint - now uses ConversationOrchestrator
  def send_message
    conversation_id = params[:conversation_id]
    message_content = params[:message]
    
    Rails.logger.info "[AiChat#send_message] conversation_id=#{conversation_id.inspect}, message_length=#{message_content&.length || 0}"
    
    # Validate message content
    if message_content.blank?
      if request.xhr? || request.headers['Accept']&.include?('json')
        render json: { error: 'Message cannot be blank' }, status: :unprocessable_entity
      else
        redirect_to ai_chat_index_path, alert: 'Message cannot be blank'
      end
      return
    end
    
    begin
      # If conversation_id provided, verify it exists and belongs to user
      if conversation_id.present?
        @conversation = current_user.ai_conversations.find_by(id: conversation_id)
      end
      
      # If no valid conversation, create a new one
      unless @conversation
        @conversation = current_user.ai_conversations.create!(
          title: "Chat #{Time.current.strftime('%b %d, %I:%M %p')}",
          session_type: 'chat',
          metadata: { created_via: 'web' }
        )
      end
      
      # Use ConversationOrchestrator for message processing
      result = ConversationOrchestrator.process_message(
        user: current_user,
        conversation_id: @conversation.id,
        content: message_content,
        modality: "text"
      )
      
      @messages = @conversation.ai_messages.order(created_at: :desc)
      
      # Return the messages view
      render 'send_message'
    rescue => e
      Rails.logger.error "[AiChat] Error sending message: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      
      # Fallback: find or create conversation and show existing messages
      @conversation = current_user.ai_conversations.first || current_user.ai_conversations.create!(
        title: "Chat #{Time.current.strftime('%b %d, %I:%M %p')}",
        session_type: 'chat',
        metadata: { created_via: 'web' }
      )
      @messages = @conversation.ai_messages.order(created_at: :desc)
      
      render 'send_message'
    end
  end
  
  def toggle_voice
    voice_setting = current_user.voice_settings.first_or_initialize
    voice_setting.enabled = !voice_setting.enabled
    voice_setting.save!
    
    redirect_back(fallback_location: ai_chat_index_path)
  end
end