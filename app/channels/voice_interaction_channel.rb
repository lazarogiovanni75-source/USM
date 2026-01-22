class VoiceInteractionChannel < ApplicationCable::Channel
  def subscribed
    # Require authentication for this channel
    reject unless current_user

    # Stream name follows "resource_id" pattern (e.g., "post_123", "user_456")
    @stream_name = params[:stream_name]
    reject unless @stream_name

    # TODO: Add stream validation if needed (pattern check, ownership, etc.)
    stream_from @stream_name
  rescue StandardError => e
    handle_channel_error(e)
    reject
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  rescue StandardError => e
    handle_channel_error(e)
  end

  # 📨 CRITICAL: ALL broadcasts MUST have 'type' field (auto-routes to handleType method)
  #
  # EXAMPLE: Send new message
  # def send_message(data)
  #   message = Message.create!(content: data['content'])
  #
  #   ActionCable.server.broadcast(
  #     @stream_name,
  #     {
  #       type: 'new-message',  # REQUIRED: routes to handleNewMessage() in frontend
  #       id: message.id,
  #       content: message.content,
  #       user_name: message.user.name,
  #       created_at: message.created_at
  #     }
  #   )
  # end

  # Voice command processing
  def process_voice_command(data)
    command_text = data['command_text']
    
    # Create voice command record
    voice_command = VoiceCommand.create!(
      user: current_user,
      command_text: command_text,
      status: 'processing'
    )
    
    # Broadcast command received confirmation
    ActionCable.server.broadcast(
      @stream_name,
      {
        type: 'command-received',
        voice_command_id: voice_command.id,
        command_text: command_text,
        status: 'processing',
        timestamp: Time.current
      }
    )
    
    # Process the command asynchronously
    ProcessVoiceCommandJob.perform_later(voice_command.id)
  rescue StandardError => e
    ActionCable.server.broadcast(
      @stream_name,
      {
        type: 'command-error',
        error: e.message,
        timestamp: Time.current
      }
    )
  end
  
  # Generate content via AI Autopilot
  def generate_content(data)
    campaign_id = data['campaign_id']
    content_type = data['content_type'] || 'post'
    platform = data['platform'] || 'general'
    
    campaign = Campaign.find(campaign_id)
    
    # Generate content using AI Autopilot
    generated_content = AiAutopilotService.new(
      action: 'generate_content',
      campaign: campaign,
      content_type: content_type,
      platform: platform
    ).call
    
    ActionCable.server.broadcast(
      @stream_name,
      {
        type: 'content-generated',
        content: generated_content,
        campaign_id: campaign_id,
        timestamp: Time.current
      }
    )
  rescue StandardError => e
    ActionCable.server.broadcast(
      @stream_name,
      {
        type: 'generation-error',
        error: e.message,
        timestamp: Time.current
      }
    )
  end
  
  # Create new campaign via voice
  def create_campaign(data)
    campaign_data = data['campaign_data']
    
    campaign = Campaign.create!(
      user: current_user,
      name: campaign_data['name'],
      description: campaign_data['description'],
      target_audience: campaign_data['target_audience'],
      budget: campaign_data['budget'],
      start_date: campaign_data['start_date'],
      end_date: campaign_data['end_date']
    )
    
    ActionCable.server.broadcast(
      @stream_name,
      {
        type: 'campaign-created',
        campaign: campaign,
        timestamp: Time.current
      }
    )
  rescue StandardError => e
    ActionCable.server.broadcast(
      @stream_name,
      {
        type: 'campaign-error',
        error: e.message,
        timestamp: Time.current
      }
    )
  end
  
  # Send status update
  def update_status(data)
    ActionCable.server.broadcast(
      @stream_name,
      {
        type: 'status-update',  # Routes to handleStatusUpdate() in frontend
        status: data['status']
      }
    )
  end
  private

  def current_user
    @current_user ||= connection.current_user
  end
end
