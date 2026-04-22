class AssistantConversation < ApplicationRecord
  belongs_to :user

  before_save :generate_title_if_needed, if: :first_message?

  def messages_array
    JSON.parse(messages || '[]')
  end

  def add_message!(role, content)
    msgs = messages_array
    msgs << { role: role, content: content, timestamp: Time.current.iso8601 }
    # Keep last 20 messages to avoid token overflow
    msgs = msgs.last(20)
    update!(messages: msgs.to_json)
    # Generate title from first user message if not set
    generate_title_from_first_message if title.blank? && msgs.count == 1 && role == 'user'
  end

  def clear!
    update!(messages: '[]')
  end

  def first_message?
    messages_array.empty?
  end

  def generate_title_from_first_message
    return if title.present?
    first_user_msg = messages_array.find { |m| m['role'] == 'user' }
    return unless first_user_msg

    content = first_user_msg['content']
    return if content.blank?

    # Generate title using AI
    prompt = "Generate a short, descriptive title (max 50 characters) for this conversation based on the user's first message. Return ONLY the title, no quotes or explanation:\n\n#{content[0..500]}"

    begin
      generated_title = LlmService.call_blocking(prompt: prompt, max_tokens: 30)
      # Clean up the title
      generated_title = generated_title.strip.gsub(/^"|"$/, '').strip
      generated_title = content.truncate(50, separator: ' ') if generated_title.blank?
      update!(title: generated_title) if generated_title.present?
    rescue => e
      Rails.logger.error "Failed to generate conversation title: #{e.message}"
      update!(title: content.truncate(50, separator: ' '))
    end
  end

  def self.load_recent(user)
    where(user: user).order(updated_at: :desc).first
  end
end
