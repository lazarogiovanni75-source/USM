class AssistantConversation < ApplicationRecord
  belongs_to :user

  def messages_array
    JSON.parse(messages || '[]')
  end

  def add_message!(role, content)
    msgs = messages_array
    msgs << { role: role, content: content, timestamp: Time.current.iso8601 }
    # Keep last 20 messages to avoid token overflow
    msgs = msgs.last(20)
    update!(messages: msgs.to_json)
  end

  def clear!
    update!(messages: '[]')
  end
end
