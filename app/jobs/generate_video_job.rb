class GenerateVideoJob < ApplicationJob
  queue_as :default

  # Accept either keyword arguments (preferred) or positional arguments for backward compatibility
  # Keyword usage: GenerateVideoJob.perform_later(prompt: "...", user_id: 1, conversation_id: 1)
  # Positional usage: GenerateVideoJob.perform_later(video.id, "topic")
  def perform(*args, **kwargs)
    # Handle keyword arguments
    if kwargs.present?
      prompt = kwargs[:prompt]
      user_id = kwargs[:user_id]
      conversation_id = kwargs[:conversation_id]
      
      user = User.find_by(id: user_id)
      conversation = AiConversation.find_by(id: conversation_id)
      
      # Create a new Video record for this generation
      video = Video.create!(
        user: user,
        title: prompt,
        status: 'pending'
      )
      
      video_id = video.id
      topic = prompt
    else
      # Handle positional arguments (backward compatibility)
      video_id = args[0]
      topic = args[1]
      video = Video.find(video_id)
      user = video.user
    end

    # Validate topic - use default if empty or nil
    topic = topic.presence || "social media content"

    # Update video status to processing
    video.update!(status: 'processing')

    # Generate video using AtlasCloudService (Seedance v1 Pro)
    atlas_service = AtlasCloudService.new
    response = atlas_service.generate_video(
      prompt: topic,
      duration: 10,
      aspect_ratio: '16:9'
    )

    # Store the task_id for status checking
    task_id = response['prediction_id']
    video.update!(
      status: 'processing',
      video_url: nil,
      prediction_url: task_id
    )

    # Broadcast progress update
    ActionCable.server.broadcast(
      "video_progress_#{video_id}",
      {
        type: 'video-progress',
        video_id: video_id,
        status: 'processing',
        message: 'Video generation started...'
      }
    )

    # Poll for completion
    wait_for_completion(video, atlas_service, task_id)

  rescue StandardError => e
    video&.update!(status: 'failed', error_message: e.message)

    ActionCable.server.broadcast(
      "video_progress_#{video_id}",
      {
        type: 'video-error',
        video_id: video_id,
        error: e.message
      }
    )

    raise
  end

  private

  def wait_for_completion(video, atlas_service, task_id)
    max_attempts = 120 # 10 minutes max for 10s videos
    attempt = 0

    while attempt < max_attempts
      sleep 5
      attempt += 1

      begin
        status_response = atlas_service.task_status(task_id)
        status = status_response['status']

        case status
        when 'success', 'succeeded'
          video.update!(
            status: 'completed',
            video_url: status_response['output']
          )

          ActionCable.server.broadcast(
            "video_progress_#{video.id}",
            {
              type: 'video-completed',
              video_id: video.id,
              video_url: video.video_url,
              message: 'Video generated successfully!'
            }
          )
          return
        when 'failed', 'error'
          error_msg = status_response['error'] || 'Video generation failed'
          video.update!(status: 'failed', error_message: error_msg)

          ActionCable.server.broadcast(
            "video_progress_#{video.id}",
            {
              type: 'video-error',
              video_id: video.id,
              error: error_msg
            }
          )
          return
        else
          # Still processing (pending, in_progress, starting, etc.)
          ActionCable.server.broadcast(
            "video_progress_#{video.id}",
            {
              type: 'video-progress',
              video_id: video.id,
              status: status,
              message: "Processing... (#{attempt * 5}s)"
            }
          )
        end
      rescue StandardError => e
        # Continue polling on transient errors
        Rails.logger.error "Error polling video status: #{e.message}"
      end
    end

    # Timeout
    video.update!(status: 'failed', error_message: 'Video generation timed out')
    ActionCable.server.broadcast(
      "video_progress_#{video.id}",
      {
        type: 'video-error',
        video_id: video.id,
        error: 'Video generation timed out'
      }
    )
  end
end
