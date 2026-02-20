# AI Autopilot Controller
class AiAutopilotController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @voice_commands = current_user.voice_commands.order(created_at: :desc).limit(20)
  end
  
  def toggle
    voice_setting = current_user.voice_settings.find_or_initialize_by(user_id: current_user.id)
    if voice_setting.persisted?
      voice_setting.update(enabled: !voice_setting.enabled)
    else
      voice_setting.save(enabled: true)
    end
    
    redirect_back(fallback_location: ai_chat_index_path, notice: voice_setting.enabled? ? "Hey Otto enabled" : "Hey Otto disabled")
  end
  
  def generate_content
    topic = params[:topic] || "social media content"
    content_type = params[:content_type] || 'post'
    generated_content = AiAutopilotService.new(
      action: 'generate_content',
      campaign: current_user.campaigns.last,
      content_type: content_type,
      platform: 'general'
    ).call
    redirect_to ai_autopilot_index_path, notice: "Content generated!"
  rescue StandardError => e
    redirect_to ai_autopilot_index_path, alert: "Error: #{e.message}"
  end
  
  def logs
    @logs = current_user.voice_commands.order(created_at: :desc).limit(100)
  end
end
