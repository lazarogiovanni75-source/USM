class VideoProgressChannel < ApplicationCable::Channel
  def subscribed
    # Require authentication for this channel
    reject unless current_user

    @stream_name = params[:stream_name]
    reject unless @stream_name

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

  # Send status update
  def update_status(data)
    ActionCable.server.broadcast(
      @stream_name,
      {
        type: 'video-progress',
        video_id: data['video_id'],
        status: data['status'],
        message: data['message']
      }
    )
  end

  private

  def current_user
    @current_user ||= connection.current_user
  end
end
