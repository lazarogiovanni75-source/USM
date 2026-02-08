# frozen_string_literal: true

module Api
  module V1
    class AiChatController < Api::BaseController
      before_action :authenticate_user!

      # POST /api/v1/ai_chat/send_message
      def send_message
        conversation = AiConversation.find(params[:conversation_id]) if params[:conversation_id].present?
        
        unless conversation
          render json: { error: "Conversation not found" }, status: :not_found
          return
        end

        message_content = params[:message]
        
        unless message_content.present?
          render json: { error: "Message content is required" }, status: :bad_request
          return
        end

        # Create user message
        user_message = conversation.messages.create!(
          role: "user",
          content: message_content
        )

        # Generate AI response
        response_content = ConversationMemoryService.call(
          conversation_id: conversation.id,
          prompt: message_content,
          action: "chat"
        )

        # Create AI message
        ai_message = conversation.messages.create!(
          role: "assistant",
          content: response_content
        )

        # Update conversation title if it's the first message
        if conversation.messages.count == 2
          conversation.update!(title: message_content.truncate(50))
        end

        render json: {
          success: true,
          user_message: {
            role: user_message.role,
            content: user_message.content,
            created_at: user_message.created_at.iso8601
          },
          ai_message: {
            role: ai_message.role,
            content: ai_message.content,
            created_at: ai_message.created_at.iso8601
          },
          conversation: {
            id: conversation.id,
            title: conversation.title
          }
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      rescue StandardError => e
        render json: { error: e.message }, status: :internal_server_error
      end

      # POST /api/v1/ai_chat/create_conversation
      def create_conversation
        conversation = AiConversation.create!(
          user: current_user,
          title: params[:title] || "New Chat"
        )

        render json: {
          success: true,
          conversation: {
            id: conversation.id,
            title: conversation.title,
            created_at: conversation.created_at.iso8601
          }
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # GET /api/v1/ai_chat/conversations
      def conversations
        conversations = current_user.ai_conversations
                                     .order(updated_at: :desc)
                                     .limit(20)

        render json: {
          success: true,
          conversations: conversations.map do |c|
            {
              id: c.id,
              title: c.title,
              updated_at: c.updated_at.iso8601,
              messages_count: c.ai_messages.count
            }
          end
        }
      end

      # GET /api/v1/ai_chat/messages/:conversation_id
      def messages
        conversation = AiConversation.find(params[:conversation_id])

        unless conversation.user == current_user
          render json: { error: "Not authorized" }, status: :forbidden
          return
        end

        messages = conversation.ai_messages.order(created_at: :asc)

        render json: {
          success: true,
          conversation: {
            id: conversation.id,
            title: conversation.title
          },
          messages: messages.map do |m|
            {
              role: m.role,
              content: m.content,
              created_at: m.created_at.iso8601
            }
          end
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Conversation not found" }, status: :not_found
      end
    end
  end
end
