class VoiceInteractionChannel < ApplicationCable::Channel
  def subscribed
    # Check if user is authenticated
    if current_user
      # Authenticated user - stream with user-specific channel
      @stream_name = params[:stream_name] || "voice_interaction_#{current_user.id}"
      stream_from @stream_name
      puts "Voice channel connected for user #{current_user.id}: #{@stream_name}"
    else
      # Unauthenticated user - use demo stream for testing
      @stream_name = params[:stream_name] || 'voice_interaction_demo'
      stream_from @stream_name
      puts "Voice channel connected (demo mode): #{@stream_name}"
    end
  rescue StandardError => e
    handle_channel_error(e)
    reject
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  rescue StandardError => e
    handle_channel_error(e)
  end

  # CRITICAL: ALL broadcasts MUST have 'type' field (auto-routes to handleType method)
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

  # Generate content via AI - use WorkflowService for unified processing
  def generate_content(data)
    campaign_id = data['campaign_id']
    content_type = data['content_type'] || 'post'
    platform = data['platform'] || 'general'

    campaign = Campaign.find(campaign_id) if campaign_id

    # Use WorkflowService for unified content generation
    result = WorkflowService.create_content_with_media(
      user: current_user,
      content_text: "Generate content for #{platform}",
      generate_image: false,
      generate_video: false
    )

    content_text = result[:caption] || result.dig(:content, :body) || "Content generated successfully"

    ActionCable.server.broadcast(
      @stream_name,
      {
        type: 'content-generated',
        content: content_text,
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

  # Generate video via AI - use WorkflowService for unified processing
  def generate_video(data)
    campaign_id = data['campaign_id']
    topic = data['topic'] || 'social media content'
    duration = data['duration'] || 30

    campaign = Campaign.find(campaign_id) if campaign_id

    # Use WorkflowService for unified video generation
    result = WorkflowService.create_content_with_media(
      user: current_user,
      content_text: topic,
      generate_image: false,
      generate_video: true
    )

    ActionCable.server.broadcast(
      @stream_name,
      {
        type: 'video-generated',
        draft_id: result[:draft]&.id,
        topic: topic,
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
