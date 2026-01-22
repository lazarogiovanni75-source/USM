import BaseChannelController from "./base_channel_controller"

/**
 * VoiceInteraction Controller - Handles WebSocket + UI for voice interaction
 *
 * Server sends JSON with 'type' field, automatically routes to handleXxx() methods
 */
export default class extends BaseChannelController {
  static targets = [
    // Add UI targets here, e.g.:
    // "output"
  ]

  static values = {
    streamName: String
  }

  declare readonly streamNameValue: string

  connect(): void {
    console.log("VoiceInteraction controller connected")

    this.createSubscription("VoiceInteractionChannel", {
      stream_name: this.streamNameValue
    })
  }

  disconnect(): void {
    this.destroySubscription()
  }

  protected channelConnected(): void {
    // Called when WebSocket connects
  }

  protected channelDisconnected(): void {
    // Called when WebSocket disconnects
  }

  // ⚡ AUTO-ROUTED HANDLERS: Server sends { type: 'xxx' } → calls handleXxx(data)
  //
  // EXAMPLE: Handle new message from server
  // protected handleNewMessage(data: any): void {
  //   console.log('New message:', data.content)
  //   // Update DOM based on data
  //   if (this.hasOutputTarget) {
  //     const messageEl = document.createElement('div')
  //     messageEl.textContent = data.content
  //     this.outputTarget.appendChild(messageEl)
  //   }
  // }

  // EXAMPLE: Handle status update from server
  // protected handleStatusUpdate(data: any): void {
  //   console.log('Status:', data.status)
  // }

  // 💡 UI METHODS: For local interactions (scroll, toggle, etc.)
  //
  // scrollToBottom(): void {
  //   if (this.hasOutputTarget) {
  //     this.outputTarget.scrollTop = this.outputTarget.scrollHeight
  //   }
  // }

  // 🎙️ AUTO-ROUTED HANDLERS: Server sends { type: 'xxx' } → calls handleXxx(data)
  //
  // Handle voice command completion
  protected handleCommandCompleted(data: any): void {
    console.log('Voice command completed:', data)
    // Update UI to show command completion status
    // This could trigger a success animation or notification
  }

  // Handle voice command failure
  protected handleCommandFailed(data: any): void {
    console.log('Voice command failed:', data)
    // Update UI to show command failure status
    // This could trigger an error message or retry prompt
  }
}
