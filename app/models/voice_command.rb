class VoiceCommand < ApplicationRecord
  belongs_to :user
  
  enum status: {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }
  
  enum command_type: {
    create_campaign: 'create_campaign',
    generate_content: 'generate_content',
    schedule_post: 'schedule_post',
    analyze_performance: 'analyze_performance',
    general_inquiry: 'general_inquiry'
  }
  
  after_create :process_command
  
  # Use existing field names
  alias_attribute :command_text, :transcribed_text
  
  private
  
  def process_command
    AiAutopilotService.new(command: self).call
  rescue StandardError => e
    update!(status: 'failed', error_message: e.message)
  end
end
