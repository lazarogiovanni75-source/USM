import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

// VoiceChatController - Handles incoming voice chat messages via ActionCable
// This controller receives broadcasts from the backend for real-time voice responses

interface VoiceChatEvent {
  type: string
  conversation_id?: number
  content?: string
  transcript?: string
  message?: string
  timestamp?: number
  error?: string
  payload?: {
    content?: string
    transcript?: string
    tool?: string
    arguments?: Record<string, any>
    result?: any
    error?: string
  }
}

export default class VoiceChatController extends Controller<HTMLElement> {
  static values = {
    userId: String,
    conversationId: String
  }

  declare readonly userIdValue: string
  declare readonly conversationIdValue: string

  private currentStreamingResponse: string = ""

  connect(): void {
    console.log("[VoiceChatController] Connected")
  }

  // This method is called when ActionCable broadcasts to the voice_chat stream
  // The voice_float_controller also listens on the same stream, so we delegate to it
  received(data: VoiceChatEvent): void {
    console.log("[VoiceChatController] Received:", data.type, data)

    // Find the voice float controller and delegate the message
    const voiceFloatController = this.findVoiceFloatController()
    if (voiceFloatController) {
      // Call the handleStreamMessage method on the voice float controller
      ;(voiceFloatController as any).handleStreamMessage(data)
    } else {
      console.log("[VoiceChatController] VoiceFloatController not found, handling directly")
      this.handleMessage(data)
    }
  }

  private handleMessage(data: VoiceChatEvent): void {
    switch (data.type) {
      case 'conversation_created':
        this.handleConversationCreated(data.conversation_id)
        break
      case 'command-received':
        this.handleCommandReceived(data.message || '')
        break
      case 'assistant_token':
      case 'chunk':
        this.handleStreamingChunk(data.content || data.payload?.content || '')
        break
      case 'assistant_complete':
      case 'complete':
        this.handleStreamComplete(data.content || data.payload?.content || '')
        break
      case 'error':
        this.handleError(data.error || data.payload?.error || 'Unknown error')
        break
      default:
        console.log("[VoiceChatController] Unknown event type:", data.type)
    }
  }

  private handleConversationCreated(conversationId?: number): void {
    console.log("[VoiceChatController] Conversation created:", conversationId)
  }

  private handleCommandReceived(message: string): void {
    console.log("[VoiceChatController] Command received:", message)
    // This is handled by voice_float_controller
  }

  private handleStreamingChunk(chunk: string): void {
    this.currentStreamingResponse += chunk
    // Update UI if needed
    this.updateResponseDisplay(this.currentStreamingResponse)
  }

  private handleStreamComplete(content: string): void {
    this.currentStreamingResponse = ""
    // This is handled by voice_float_controller
  }

  private handleError(error: string): void {
    console.error("[VoiceChatController] Error:", error)
  }

  private updateResponseDisplay(text: string): void {
    const el = document.getElementById("voice-ai-response")
    if (el && text) {
      el.innerHTML = text.replace(/\n/g, "<br>")
      el.classList.remove("hidden")
    }
  }

  private findVoiceFloatController(): any {
    // Find any element with data-controller="voice-float" and get its controller instance
    const element = document.querySelector('[data-controller="voice-float"]')
    if (element && (element as any).stimulusController) {
      return (element as any).stimulusController
    }
    return null
  }
}
