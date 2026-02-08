import { Controller } from "@hotwired/stimulus"

// Video Progress Controller - Handles video generation progress updates via ActionCable
export default class VideoProgressController extends Controller<HTMLElement> {
  static values = {
    videoId: Number,
    channelName: String
  }

  declare videoIdValue: number
  declare channelNameValue: string

  private channel: any = null

  connect(): void {
    console.log('VideoProgress connected for video:', this.videoIdValue)
    this.initializeChannel()
  }

  disconnect(): void {
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }

  private initializeChannel(): void {
    const channelName = this.channelNameValue || `video_progress_${this.videoIdValue}`

    this.channel = (window as any).ActionCable.createConsumer().subscriptions.create(
      { channel: 'VideoProgressChannel', stream_name: channelName },
      {
        connected: () => {
          console.log('Video progress channel connected:', channelName)
        },
        disconnected: () => {
          console.log('Video progress channel disconnected')
        },
        received: (data: VideoProgressMessage) => {
          this.handleProgressUpdate(data)
        }
      }
    )
  }

  private handleProgressUpdate(data: VideoProgressMessage): void {
    console.log('Video progress update:', data)

    switch (data.type) {
      case 'video-progress':
        this.handleVideoProgress(data)
        break
      case 'video-completed':
        this.handleVideoCompleted(data)
        break
      case 'video-error':
        this.handleVideoError(data)
        break
    }
  }

  // Handle video progress updates
  handleVideoProgress(data: VideoProgressMessage): void {
    // Dispatch event for other controllers to listen to
    this.dispatch('progress', {
      detail: {
        videoId: this.videoIdValue,
        status: data.status,
        message: data.message
      }
    })
  }

  // Handle video completion
  handleVideoCompleted(data: VideoProgressMessage): void {
    // Dispatch completion event
    this.dispatch('completed', {
      detail: {
        videoId: this.videoIdValue,
        videoUrl: data.video_url,
        message: data.message
      }
    })
  }

  // Handle video generation errors
  handleVideoError(data: VideoProgressMessage): void {
    // Dispatch error event
    this.dispatch('error', {
      detail: {
        videoId: this.videoIdValue,
        error: data.error
      }
    })
  }
}

// Video progress message interface
interface VideoProgressMessage {
  type: 'video-progress' | 'video-completed' | 'video-error'
  video_id?: number
  status?: string
  message?: string
  video_url?: string
  error?: string
}
