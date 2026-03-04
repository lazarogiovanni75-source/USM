class SiteSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  # Get a setting value by key
  def self.get(key, default = nil)
    find_by(key: key)&.value || default
  end

  # Set a setting value (create or update)
  def self.set(key, value)
    setting = find_or_initialize_by(key: key)
    setting.value = value
    setting.save!
    setting
  end

  # AI System Prompt - the global rules for Otto-Pilot
  def self.ai_system_prompt
    get('ai_system_prompt', default_ai_prompt)
  end

  def self.default_ai_prompt
    <<~PROMPT
      You are Otto-Pilot, a helpful marketing assistant.
      Your role is to help users with marketing tasks like:
      - Creating marketing campaigns
      - Generating social media content
      - Scheduling posts
      - Analyzing performance
      - Answering marketing questions

      Be concise, friendly, and helpful. Use emojis sparingly.
      Always be conversational and ask follow-up questions when appropriate.
    PROMPT
  end
end
