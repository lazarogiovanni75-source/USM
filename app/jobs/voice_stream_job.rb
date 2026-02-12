# frozen_string_literal: true

# Voice streaming job that handles conversation history with streaming LLM responses
# Usage:
#   VoiceStreamJob.perform_later(
#     stream_name: 'voice_chat_123',
#     prompt: "User message",
#     system: "System prompt...",
#     conversation_id: 123,
#     user_id: 456,
#     conversation_history: [...]
#   )
#
# Broadcasts via ActionCable:
#   - type: 'chunk' → client calls handleChunk(data)
#   - type: 'complete' → client calls handleComplete(data)
#   - type: 'error' → client calls handleError(data)
class VoiceStreamJob < ApplicationJob
  queue_as :llm

  retry_on Net::ReadTimeout, wait: 5.seconds, attempts: 3
  retry_on StandardError, wait: 5.seconds, attempts: 2

  def perform(stream_name:, prompt:, system: nil, conversation_id: nil, user_id: nil, conversation_history: nil, **options)
    full_content = ""

    begin
      # Build the full prompt with conversation history
      full_prompt = build_prompt(prompt, conversation_history)

      # Call LLM service with streaming
      LlmService.call(
        prompt: full_prompt,
        system: system,
        **options
      ) do |chunk_data|
        # Handle chunk data (can be string or hash with :content)
        content = chunk_data.is_a?(Hash) ? chunk_data[:content] : chunk_data
        if content.present?
          full_content += content
          ActionCable.server.broadcast(stream_name, {
            type: 'chunk',
            chunk: content
          })
        end
      end

      # Broadcast completion
      ActionCable.server.broadcast(stream_name, {
        type: 'complete',
        content: full_content,
        conversation_id: conversation_id
      })

      # Save assistant message to conversation if conversation_id provided
      if conversation_id && full_content.present?
        save_assistant_message(conversation_id, full_content)
      end

    rescue StandardError => e
      Rails.logger.error "VoiceStreamJob error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      ActionCable.server.broadcast(stream_name, {
        type: 'error',
        error: e.message
      })
      raise
    end
  end

  private

  def build_prompt(current_message, conversation_history)
    return current_message if conversation_history.blank?

    history_text = conversation_history.map do |msg|
      role = msg['role'] == 'user' ? 'User' : 'Assistant'
      "#{role}: #{msg['content']}"
    end.join("\n")

    "#{current_message}\n\nConversation History:\n#{history_text}"
  end

  def save_assistant_message(conversation_id, content)
    return if conversation_id.blank? || content.blank?

    conversation = AiConversation.find_by(id: conversation_id)
    return unless conversation

    conversation.ai_messages.create!(
      role: 'assistant',
      content: content,
      tokens_used: estimate_tokens(content)
    )
  rescue StandardError => e
    Rails.logger.warn "Failed to save assistant message: #{e.message}"
  end

  def estimate_tokens(text)
    (text.to_s.length / 4.0).ceil
  end
end
