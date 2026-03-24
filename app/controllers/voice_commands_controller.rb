class VoiceCommandsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_voice_command, only: [:show, :execute]

  def index
    @voice_commands = current_user.voice_commands.order(created_at: :desc)
  end

  def show
    # HTML response is default, no respond_to needed
  end

  def create
    command_text = params[:command_text] ||
                   params[:transcript] ||
                   params.dig(:voice_command, :command_text)

    if command_text.blank?
      # Return error via turbo_stream if requested, otherwise raise error
      if request.format == :json || request.headers['Accept']&.include?('application/json')
        render partial: 'error', status: :bad_request, locals: { error: "Command text is required" }
      else
        head :bad_request
      end
      return
    end

    @voice_command = current_user.voice_commands.build(
      transcribed_text: command_text,
      status: :pending,
      command_type: detect_command_type(command_text)
    )

    if @voice_command.save
      ProcessVoiceCommandJob.perform_later(@voice_command.id)
      # For turbo stream, render a success message
      # For traditional requests, use flash or redirect
      flash[:notice] = "Voice command queued for processing"
      redirect_to voice_commands_path
    else
      flash[:error] = @voice_command.errors.full_messages.join(", ")
      redirect_to voice_commands_path, status: :unprocessable_entity
    end
  end

  def execute
    @voice_command.update!(status: :pending, error_message: nil)
    ProcessVoiceCommandJob.perform_later(@voice_command.id)
    flash[:notice] = "Command is being executed."
    redirect_to voice_commands_path
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
