class VoiceCommandsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_voice_command, only: [:show, :execute]

  def index
    @voice_commands = current_user.voice_commands.order(created_at: :desc)
  end

  def show
    respond_to do |format|
      format.html
      format.json do
        render json: {
          id: @voice_command.id,
          command_text: @voice_command.transcribed_text,
          command_type: @voice_command.command_type,
          status: @voice_command.status,
          result: @voice_command.result,
          error_message: @voice_command.error_message,
          created_at: @voice_command.created_at
        }
      end
    end
  end

  def create
    command_text = params[:command_text] ||
                   params[:transcript] ||
                   params.dig(:voice_command, :command_text)

    if command_text.blank?
      render json: { success: false, error: "Command text is required" }, status: :bad_request
      return
    end

    @voice_command = current_user.voice_commands.build(
      transcribed_text: command_text,
      status: :pending,
      command_type: detect_command_type(command_text)
    )

    if @voice_command.save
      ProcessVoiceCommandJob.perform_later(@voice_command.id)
      render json: {
        success: true,
        voice_command_id: @voice_command.id,
        command_type: @voice_command.command_type,
        status: @voice_command.status
      }
    else
      render json: {
        success: false,
        errors: @voice_command.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def execute
    @voice_command.update!(status: :pending, error_message: nil)
    ProcessVoiceCommandJob.perform_later(@voice_command.id)

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          status: "processing",
          voice_command_id: @voice_command.id
        }
      end
      format.html { redirect_to voice_commands_path, notice: "Command is being executed." }
    end
  end

  private

  def set_voice_command
    @voice_command = current_user.voice_commands.find(params[:id])
  end

  def detect_command_type(text)
    return :general_inquiry unless text.present?

    text_lower = text.downcase
    if text_lower.match?(/create|make|build|launch.*campaign/)
      :create_campaign
    elsif text_lower.match?(/generate|write|create|draft.*content|post|caption/)
      :generate_content
    elsif text_lower.match?(/image|picture|photo|visual/)
      :generate_image
    elsif text_lower.match?(/video|clip|film|reel/)
      :generate_video
    elsif text_lower.match?(/schedule|post.*at|publish|when/)
      :schedule_post
    elsif text_lower.match?(/analyz|performance|stats|metrics|how.*doing/)
      :analyze_performance
    else
      :general_inquiry
    end
  end
end
