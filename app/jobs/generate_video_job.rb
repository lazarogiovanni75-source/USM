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

    # Generate video using AtlasCloudService (Google Veo 3.1 Lite)
    atlas_service = AtlasCloudService.new
    response = atlas_service.generate_video(
      prompt: topic,
      duration: 5,
      aspect_ratio: '16:9'
    )

    # Store the task_id for status checking
    task_id = response['task_id']
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

        Rails.logger.info "[GenerateVideoJob] Poll #{attempt}: status=#{status}, output=#{status_response['output']&.to_s&.[0..80]}"

        case status
        when 'success', 'succeeded', 'completed', 'finished'
          # Download video to permanent storage before updating record
          output_url = status_response['output']
          permanent_url = nil
          
          if output_url.present?
            begin
              permanent_url = download_video_to_storage(video, output_url)
              video.update!(
                status: 'completed',
                video_url: permanent_url,
                media_url: permanent_url
              )
              Rails.logger.info "[GenerateVideoJob] Video downloaded to S3: #{permanent_url}"
            rescue => e
              Rails.logger.error "[GenerateVideoJob] Failed to download video: #{e.message} - using original URL"
              permanent_url = output_url
              video.update!(
                status: 'completed',
                video_url: output_url,
                media_url: output_url
              )
            end
          else
            video.update!(status: 'failed', error_message: 'No output URL in response')
            ActionCable.server.broadcast(
              "video_progress_#{video.id}",
              { type: 'video-error', video_id: video.id, error: 'No video URL returned' }
            )
            return
          end

          # Also save to Drafts so user can find it at /drafts
          if video.user.present?
            draft = DraftContent.create!(
              user: video.user,
              title: "AI Video: #{video.title.to_s.truncate(50)}",
              content: "Video generated from prompt: #{video.title}\n\nVideo URL: #{permanent_url}",
              content_type: 'video',
              platform: 'general',
              status: 'draft',
              metadata: {
                video_url: permanent_url,
                prompt: video.title,
                video_id: video.id,
                generated_at: Time.current.iso8601
              }
            )
            Rails.logger.info "[GenerateVideoJob] Video saved to Drafts: #{draft.id}"
          end

          ActionCable.server.broadcast(
            "video_progress_#{video.id}",
            {
              type: 'video-completed',
              video_id: video.id,
              video_url: permanent_url,
              draft_id: draft&.id,
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

  # Download video from temporary URL and upload to S3/ActiveStorage for permanent access
  def download_video_to_storage(video, temp_url)
    require 'open-uri'
    require 'tempfile'

    Rails.logger.info "[GenerateVideoJob] Downloading video from #{temp_url[0..80]}..."

    # Download with SSL verification disabled for Alibaba Cloud URLs
    ssl_verify_mode = (temp_url.include?('aliyuncs') || temp_url.include?('oss-')) ? 
      OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER

    downloaded_file = URI.open(temp_url, ssl_verify_mode: ssl_verify_mode)
    
    # Create temp file
    temp_file = Tempfile.new(['video', '.mp4'], binmode: true)
    temp_file.write(downloaded_file.read)
    temp_file.close

    # Generate unique filename
    filename = "video_#{video.id}_#{Time.current.to_i}.mp4"

    # Attach to ActiveStorage (S3 in production)
    video.media.attach(
      io: File.open(temp_file.path),
      filename: filename,
      content_type: 'video/mp4'
    )

    # Return the permanent S3 URL
    permanent_url = video.media.url

    # Clean up temp file
    temp_file.unlink
    
    Rails.logger.info "[GenerateVideoJob] Video uploaded to S3, URL: #{permanent_url[0..80]}..."
    
    permanent_url
  rescue => e
    Rails.logger.error "[GenerateVideoJob] Download failed: #{e.class} - #{e.message}"
    raise
  end
end
