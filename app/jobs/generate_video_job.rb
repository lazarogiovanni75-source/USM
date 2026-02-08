class GenerateVideoJob < ApplicationJob
  queue_as :default

  def perform(video_id, topic)
    video = Video.find(video_id)
    user = video.user

    # Update video status to processing
    video.update!(status: 'processing')

    # Generate video using SoraService
    sora_service = SoraService.new
    response = sora_service.generate_video(prompt: topic, duration: '5s')

    # Store the prediction URL for status checking
    video.update!(
      status: 'processing',
      video_url: response['output'] || response['urls']&.dig('get'),
      prediction_url: response['urls']&.dig('get')
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

    # Poll for completion (simplified approach)
    wait_for_completion(video, sora_service)

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

  def wait_for_completion(video, sora_service)
    max_attempts = 60 # 5 minutes max
    attempt = 0

    while attempt < max_attempts
      sleep 5
      attempt += 1

      begin
        if video.prediction_url
          status_response = sora_service.get_prediction(video.prediction_url)
          status = status_response['status']

          case status
          when 'succeeded'
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
            # Still processing
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
