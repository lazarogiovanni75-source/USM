# frozen_string_literal: true

module Api
  module V1
    class AiChatController < Api::BaseController
      before_action :authenticate_user!
      
      # POST /api/v1/ai_chat/stream_message
      def stream_message
        conversation_id = params[:conversation_id]
        
        # Verify conversation belongs to current user
        conversation = current_user.ai_conversations.find_by(id: conversation_id)
        
        unless conversation
          render json: { error: "Conversation not found" }, status: :not_found
          return
        end

        message_content = params[:message]
        
        unless message_content.present?
          render json: { error: "Message content is required" }, status: :bad_request
          return
        end

        stream_name = "ai_chat_#{conversation.id}"

        begin
          # Use ConversationOrchestrator for ALL AI processing
          ConversationOrchestrator.process_message(
            user: current_user,
            conversation_id: conversation.id,
            content: message_content,
            modality: "text",
            stream_channel: stream_name
          )

          # Update conversation title if first message
          if conversation.ai_messages.count == 2
            conversation.update!(title: message_content.truncate(50))
          end
          
          # Get the messages we just created
          user_message = conversation.ai_messages.where(role: "user").last
          ai_message = conversation.ai_messages.where(role: "assistant").last
          
          render json: {
            success: true,
            user_message: {
              role: user_message&.role,
              content: user_message&.content,
              created_at: user_message&.created_at&.iso8601
            },
            ai_message: {
              role: ai_message&.role,
              content: ai_message&.content,
              created_at: ai_message&.created_at&.iso8601
            }
          }
          
        rescue StandardError => e
          Rails.logger.error "[stream_message] Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
          
          ActionCable.server.broadcast(stream_name, {
            type: 'error',
            error: e.message
          })
          
          render json: { 
            error: e.message
          }, status: :internal_server_error
        end
      end

      # POST /api/v1/ai_chat/confirm_tool
      def confirm_tool
        audit_id = params[:audit_id]
        confirmed = params[:confirmed] == true || params[:confirmed] == 'true'
        
        audit_record = AuditExecution.find_by(id: audit_id, user: current_user)
        
        unless audit_record
          render json: { error: "Pending execution not found" }, status: :not_found
          return
        end
        
        unless audit_record.status == 'awaiting_confirmation'
          render json: { error: "Execution is not awaiting confirmation" }, status: :bad_request
          return
        end
        
        stream_name = "ai_chat_#{audit_record.session_id.split('_').first}"
        
        if confirmed
          dispatcher = AiFunctionDispatcher.new(user: current_user)
          
          begin
            result = dispatcher.execute_confirmed(
              audit_record.tool_name,
              audit_record.parameters.except('risk_level')
            )
            
            ActionCable.server.broadcast(stream_name, {
              type: 'tool_confirmed',
              tool_name: audit_record.tool_name,
              result: result
            })
            
            render json: {
              success: true,
              message: "#{audit_record.tool_name} executed successfully",
              result: result
            }
            
          rescue => e
            ActionCable.server.broadcast(stream_name, {
              type: 'error',
              error: e.message
            })
            
            render json: { error: e.message }, status: :internal_server_error
          end
        else
          audit_record.reject!
          
          ActionCable.server.broadcast(stream_name, {
            type: 'tool_rejected',
            tool_name: audit_record.tool_name
          })
          
          render json: {
            success: true,
            message: "#{audit_record.tool_name} was rejected"
          }
        end
      end

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

        # Create user message via model (which uses raw SQL)
        user_message = conversation.ai_messages.create!(
          role: "user",
          content: message_content
        )

        # Generate AI response
        response_content = ConversationMemoryService.call(
          conversation_id: conversation.id,
          prompt: message_content,
          action: "chat"
        )

        # Create AI message via model (which uses raw SQL)
        ai_message = conversation.ai_messages.create!(
          role: "assistant",
          content: response_content
        )

        # Update conversation title if it's the first message
        if conversation.ai_messages.count == 2
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

      # POST /api/v1/ai_chat/list_conversations
      def list_conversations
        conversations = current_user.ai_conversations
          .order(updated_at: :desc)
          .limit(20)

        render json: {
          success: true,
          conversations: conversations.map do |c|
            {
              id: c.id,
              title: c.title,
              session_type: c.session_type,
              created_at: c.created_at.iso8601,
              updated_at: c.updated_at.iso8601,
              message_count: c.ai_messages.count
            }
          end
        }
      end

      # DELETE /api/v1/ai_chat/:id
      def destroy
        conversation = current_user.ai_conversations.find(params[:id])
        conversation.destroy!
        
        render json: { success: true }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Conversation not found" }, status: :not_found
      rescue StandardError => e
        render json: { error: e.message }, status: :internal_server_error
      end

      private

      def build_system_prompt(conversation)
        base_prompt = SiteSetting.ai_system_prompt rescue "You are a helpful AI assistant."
        subscription_info = ""
        if current_user.subscription_plan.present?
          plan_name = current_user.subscription_plan.is_a?(String) ? current_user.subscription_plan : current_user.subscription_plan.name
          subscription_info = "\n\nUser Subscription: #{plan_name}"
        end
        user_info = "\n\nUser: #{current_user.email}"
        base_prompt + subscription_info + user_info
      end
    end
  end
end
