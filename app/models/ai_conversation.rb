# frozen_string_literal: true

class AiConversation < ApplicationRecord
  belongs_to :user
  has_many :ai_messages, -> { order(created_at: :asc) }, dependent: :destroy

  validates :title, presence: true
  validates :session_type, inclusion: { in: %w[general chat voice campaign] }, allow_nil: true

  before_validation :set_defaults

  # Memory and context tracking
  def get_from_memory(key)
    memory_summary[key]
  end

  def set_to_memory(key, value)
    update!(memory_summary: memory_summary.merge(key => value))
  end

  def conversation_length
    ai_messages.count
  end

  def recent_messages(limit = 10)
    ai_messages.order(created_at: :desc).limit(limit)
  end

  def archive!
    update!(archived: true, archived_at: Time.current)
  end

  def unarchive!
    update!(archived: false, archived_at: nil)
  end

  private

  def set_defaults
    self.title ||= "AI Chat"
    self.session_type ||= "general"
    self.metadata ||= {}
    self.context ||= {}
    self.memory_summary ||= {}
    self.session_metadata ||= {}
  end
end
