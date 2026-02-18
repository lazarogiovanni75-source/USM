# frozen_string_literal: true

module Api
  module V1
    class AiChatController < Api::BaseController
      before_action :authenticate_user!
      
      # POST /api/v1/ai_chat/stream_message
      # Streaming version - broadcasts tokens as they arrive
      # Supports tool/function calling with risk-based execution
      def stream_message
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

        # Create user message immediately
        user_message = conversation.messages.create!(
          role: "user",
          content: message_content
        )

        # Stream name for this conversation
        stream_name = "ai_chat_#{conversation.id}"
        session_id = "#{conversation.id}_#{Time.current.to_i}"

        # Broadcast that AI is typing
        ActionCable.server.broadcast(stream_name, {
          type: 'typing',
          status: true
        })

        # Build context with conversation history
        system_prompt = build_system_prompt(conversation)
        context_messages = get_conversation_context(conversation)
        
        # Get tool definitions for this user
        tools = AiToolDefinitions.for_user(current_user)
        
        # Create function dispatcher with session tracking
        dispatcher = AiFunctionDispatcher.new(
          user: current_user,
          session_id: session_id,
          conversation_id: conversation.id
        )
        
        # Tool handler with risk-aware execution
        tool_handler = ->(tool_name, args) {
          Rails.logger.info "[stream_message] Tool called: #{tool_name}"
          
          # Broadcast tool call to frontend
          ActionCable.server.broadcast(stream_name, {
            type: 'tool_call',
            tool_name: tool_name,
            arguments: args
          })
          
          begin
            # Try to execute the tool
            result = dispatcher.dispatch(tool_name, args)
            
            # Broadcast result
            ActionCable.server.broadcast(stream_name, {
              type: 'tool_result',
              tool_name: tool_name,
              result: result
            })
            
            result
            
          rescue ConfirmationRequiredError => e
            # High-risk tool - require user confirmation
            Rails.logger.info "[stream_message] Confirmation required for #{tool_name}"
            
            ActionCable.server.broadcast(stream_name, {
              type: 'confirmation_required',
              tool_name: e.tool_name,
              arguments: e.arguments,
              risk_level: e.risk_level,
              audit_id: e.audit_id
            })
            
            # Return a message indicating confirmation is needed
            {
              success: false,
              confirmation_required: true,
              tool_name: e.tool_name,
              message: "Please confirm to proceed with #{e.tool_name}"
            }
            
          rescue ExecutionLimitError => e
            Rails.logger.error "[stream_message] Execution limit: #{e.message}"
            
            ActionCable.server.broadcast(stream_name, {
              type: 'error',
              error: e.message
            })
            
            { success: false, error: e.message }
          end
        }

        # Create placeholder assistant message
        ai_message = conversation.messages.create!(
          role: "assistant",
          content: ""
        )

        # Stream the response
        full_content = ""
        
        begin
          LlmService.new(
            prompt: message_content,
            system: system_prompt,
            messages: context_messages,
            tools: tools,
            tool_handler: tool_handler
          ).call_stream do |chunk|
            full_content += chunk
            
            ActionCable.server.broadcast(stream_name, {
              type: 'chunk',
              chunk: chunk,
              message_id: ai_message.id
            })
          end
          
          ai_message.update!(content: full_content)
          
          ActionCable.server.broadcast(stream_name, {
            type: 'complete',
            content: full_content,
            message_id: ai_message.id,
            created_at: ai_message.created_at.iso8601
          })
          
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
            }
          }
          
        rescue StandardError => e
          ActionCable.server.broadcast(stream_name, {
            type: 'error',
            error: e.message
          })
          
          ai_message.update!(content: "Sorry, I encountered an error: #{e.message}")
          
          render json: { 
            error: e.message,
            user_message: {
              role: user_message.role,
              content: user_message.content,
              created_at: user_message.created_at.iso8601
            }
          }, status: :internal_server_error
        end
      end

      # POST /api/v1/ai_chat/confirm_tool
      # Confirm a pending high-risk tool execution
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
          # Execute the tool
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
          # User rejected
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
      # Non-streaming version (fallback)
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

      private

      # Build system prompt with conversation context
      def build_system_prompt(conversation)
        system_prompt = <<~PROMPT
          You are Otto, a helpful AI marketing assistant for a social media management platform.
          You help users with:
          - Creating and managing marketing campaigns
          - Generating social media content (posts, stories, captions)
          - Scheduling posts across platforms
          - Analyzing engagement and performance
          - Providing marketing strategy advice
          
          Be friendly, concise, and actionable. When appropriate, suggest specific actions the user can take.
          If you need to create content, mention what platforms it's suitable for.
        PROMPT
        
        # Add conversation context if exists
        if conversation.context.present?
          system_prompt += "\n\nCurrent context: #{conversation.context}"
        end
        
        system_prompt.strip
      end

      # Get conversation history within token limit
      def get_conversation_context(conversation, max_tokens: 8000)
        # Approximate: 1 token ≈ 4 characters
        max_chars = max_tokens * 4
        
        messages = conversation.messages
          .where.not(role: 'system')
          .order(created_at: :asc)
          .limit(20) # Start with last 20 messages
        
        # Trim from oldest until under limit
        while total_chars(messages) > max_chars && messages.count > 1
          messages = messages.offset(1)
        end
        
        messages.map { |m| { role: m.role, content: m.content } }
      end

      def total_chars(messages)
        messages.sum { |m| m.content.to_s.length }
      end
    end
  end
end
