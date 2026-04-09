# frozen_string_literal: true

class AiMessage < ApplicationRecord
  belongs_to :ai_conversation

  validates :role, presence: true, inclusion: { in: %w[user assistant system tool] }
  validates :content, presence: true

  # Memory and context tracking
  MESSAGE_TYPES = %w[text image file link code].freeze
  validates :message_type, inclusion: { in: MESSAGE_TYPES }, allow_nil: true

  before_validation :set_defaults, :estimate_tokens

  def set_defaults
    self.message_type ||= 'text'
    self.metadata ||= {}
  end

  def estimate_tokens
    self.tokens_used ||= (content.length / 4.0).ceil
  end

  def is_user_message?
    role == 'user'
  end

  def is_ai_message?
    role == 'assistant'
  end

  def is_system_message?
    role == 'system'
  end

  def previous_message
    ai_conversation.ai_messages.where('created_at < ?', created_at).order(created_at: :desc).first
  end

  def next_message
    ai_conversation.ai_messages.where('created_at > ?', created_at).order(created_at: :asc).first
  end

  def self.build_conversation_context(conversation, limit = 10)
    recent_messages = conversation.ai_messages
      .order(created_at: :desc)
      .limit(limit)
      .reverse

    recent_messages.map do |message|
      {
        role: message.role,
        content: message.content,
        timestamp: message.created_at,
        message_type: message.message_type || 'text'
      }
    end
  end

  def self.build_memory_context(conversation)
    context = {
      conversation_summary: conversation.memory_summary || {},
      recent_topics: conversation.get_from_memory('conversation_topics') || [],
      user_preferences: conversation.get_from_memory('user_preferences') || {},
      conversation_length: conversation.conversation_length,
      last_activity: conversation.updated_at
    }

    context[:recent_messages] = build_conversation_context(conversation, 5)
    context
  end
end
