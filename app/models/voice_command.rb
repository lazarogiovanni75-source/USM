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
    generate_image: 'generate_image',
    generate_video: 'generate_video',
    schedule_post: 'schedule_post',
    analyze_performance: 'analyze_performance',
    general_inquiry: 'general_inquiry'
  }
  
  after_create :process_command
  
  # Use existing field names
  alias_attribute :command_text, :transcribed_text
  alias_attribute :transcript, :transcribed_text
  
  private
  
  def process_command
    # Route voice commands through Otto-Pilot for unified AI processing
    response = HTTParty.post(
      "#{ENV.fetch('APP_URL', 'http://localhost:3000')}/api/v1/otto/execute",
      body: { message: command_text },
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{user.token}"
      }
    )
    
    if response.success?
      update!(status: 'completed', response_text: response.parsed_response['reply'])
    else
      update!(status: 'failed', response_text: 'Failed to process command. Please try again.')
    end
  rescue StandardError => e
    update!(status: 'failed', error_message: e.message)
  end
end
