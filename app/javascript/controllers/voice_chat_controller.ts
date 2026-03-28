import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

// VoiceChatController - Handles conversational voice chat with Claude
// Uses: Whisper (STT), Claude (AI), Google Cloud TTS (TTS)

interface Message {
  id: string
  role: 'user' | 'assistant'
  content: string
  timestamp: Date
}

interface VoiceChatEvent {
  type: string
  content?: string
  error?: string
  audio_url?: string
}

export default class VoiceChatController extends Controller<HTMLElement> {
  static targets = ["textInput", "voiceButton"]

  declare readonly textInputTarget: HTMLInputElement
  declare readonly voiceButtonTarget: HTMLButtonElement

  private messages: Message[] = []
  private mediaRecorder: MediaRecorder | null = null
  private audioChunks: Blob[] = []
  private isRecording = false
  private conversationContainer: HTMLElement | null = null
  private messagesList: HTMLElement | null = null
  private ttsAudio: HTMLAudioElement | null = null

  // Loading state elements
  private transcribingState: HTMLElement | null = null
  private thinkingState: HTMLElement | null = null
  private synthesizingState: HTMLElement | null = null
  private loadingStates: HTMLElement | null = null

  connect(): void {
    this.conversationContainer = document.getElementById("conversation-container")
    this.messagesList = document.getElementById("messages-list")
    this.ttsAudio = document.getElementById("tts-audio") as HTMLAudioElement
    this.transcribingState = document.getElementById("transcribing-state")
    this.thinkingState = document.getElementById("thinking-state")
    this.synthesizingState = document.getElementById("synthesizing-state")
    this.loadingStates = document.getElementById("loading-states")

    // Setup audio ended listener
    if (this.ttsAudio) {
      this.ttsAudio.addEventListener("ended", () => this.onAudioEnded())
    }

    // Setup text input enter key
    this.textInputTarget.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        this.sendText()
      }
    })
  }

  // Start recording when button is pressed
  async startRecording(event: MouseEvent | TouchEvent): Promise<void> {
    event.preventDefault()

    if (this.isRecording) return

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.mediaRecorder = new MediaRecorder(stream, {
        mimeType: this.getMimeType()
      })
      this.audioChunks = []

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) {
          this.audioChunks.push(e.data)
        }
      }

      this.mediaRecorder.onstop = () => this.processRecording()
      this.mediaRecorder.start()

      this.isRecording = true
      this.updateRecordingUI(true)
      this.setStatus("Recording...")

    } catch (error) {
      console.error("[VoiceChat] Failed to start recording:", error)
      this.showError("Could not access microphone. Please check permissions.")
    }
  }

  // Stop recording when button is released
  stopRecording(event: MouseEvent | TouchEvent): void {
    event.preventDefault()

    if (!this.isRecording || !this.mediaRecorder) return

    this.mediaRecorder.stop()
    this.mediaRecorder.stream.getTracks().forEach(track => track.stop())
    this.isRecording = false
    this.updateRecordingUI(false)
  }

  private getMimeType(): string {
    if (MediaRecorder.isTypeSupported("audio/webm")) {
      return "audio/webm"
    }
    if (MediaRecorder.isTypeSupported("audio/mp4")) {
      return "audio/mp4"
    }
    return "audio/ogg"
  }

  private updateRecordingUI(isRecording: boolean): void {
    const micIcon = document.getElementById("mic-icon")
    const stopIcon = document.getElementById("stop-icon")
    const recordingRing = document.getElementById("recording-ring")

    if (isRecording) {
      micIcon?.classList.add("hidden")
      stopIcon?.classList.remove("hidden")
      recordingRing?.classList.remove("opacity-0", "scale-100")
      recordingRing?.classList.add("opacity-100", "scale-110")
      this.voiceButtonTarget.classList.add("animate-pulse")
    } else {
      micIcon?.classList.remove("hidden")
      stopIcon?.classList.add("hidden")
      recordingRing?.classList.add("opacity-0", "scale-100")
      recordingRing?.classList.remove("opacity-100", "scale-110")
      this.voiceButtonTarget.classList.remove("animate-pulse")
    }
  }

  private async processRecording(): Promise<void> {
    if (this.audioChunks.length === 0) {
      this.showError("No audio recorded")
      return
    }

    const audioBlob = new Blob(this.audioChunks, { type: this.getMimeType() })
    await this.transcribeAudio(audioBlob)
  }

  // Send text message
  async sendText(): Promise<void> {
    const text = this.textInputTarget.value.trim()
    if (!text) return

    this.textInputTarget.value = ""
    await this.sendMessage(text)
  }

  // Main message handler
  private async sendMessage(text: string): Promise<void> {
    // Add user message to UI
    this.addMessageToUI("user", text)

    // Show thinking state
    this.showLoadingState("thinking")

    try {
      // Send to backend
      const response = await fetch("/chat", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCSRFToken()
        },
        body: JSON.stringify({ message: text })
      })

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || "Failed to get response")
      }

      // Hide thinking state
      this.hideAllLoadingStates()

      // Add assistant response to UI
      this.addMessageToUI("assistant", data.response)

      // Show synthesizing state and play audio
      this.showLoadingState("synthesizing")
      await this.playAudioResponse(data.response)

    } catch (error) {
      console.error("[VoiceChat] Error:", error)
      this.hideAllLoadingStates()
      this.addMessageToUI("assistant", `Sorry, I encountered an error: ${error instanceof Error ? error.message : "Unknown error"}`)
    }
  }

  // Transcribe audio using Whisper
  private async transcribeAudio(audioBlob: Blob): Promise<void> {
    this.showLoadingState("transcribing")

    try {
      const formData = new FormData()
      formData.append("audio", audioBlob, "recording.webm")

      const response = await fetch("/transcribe", {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.getCSRFToken()
        },
        body: formData
      })

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || "Transcription failed")
      }

      const transcribedText = data.text || data.transcription?.[0]?.text

      if (!transcribedText || transcribedText.trim().length < 3) {
        this.hideAllLoadingStates()
        this.setStatus("Could not understand audio. Please try again.")
        return
      }

      this.hideAllLoadingStates()
      this.setStatus("Ready")
      
      // Send transcribed text to Claude
      await this.sendMessage(transcribedText)

    } catch (error) {
      console.error("[VoiceChat] Transcription error:", error)
      this.hideAllLoadingStates()
      this.showError("Failed to transcribe audio")
    }
  }

  // Play audio response from Google Cloud TTS
  private async playAudioResponse(text: string): Promise<void> {
    try {
      // Call backend to generate TTS audio
      const response = await fetch("/speak", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCSRFToken()
        },
        body: JSON.stringify({ text: text })
      })

      if (!response.ok) {
        throw new Error("Failed to generate speech")
      }

      // Create blob URL and play
      const audioBlob = await response.blob()
      const audioUrl = URL.createObjectURL(audioBlob)

      if (this.ttsAudio) {
        this.ttsAudio.src = audioUrl
        this.ttsAudio.play()
      }

    } catch (error) {
      console.error("[VoiceChat] TTS error:", error)
      this.hideAllLoadingStates()
      // Don't show error to user, just log it
      // The text response is already shown
    }
  }

  private onAudioEnded(): void {
    this.hideAllLoadingStates()
    this.setStatus("Ready")
  }

  // Add message to conversation UI
  private addMessageToUI(role: "user" | "assistant", content: string): void {
    if (!this.messagesList) return

    const messageId = `msg-${Date.now()}`
    const time = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })

    const messageHTML = role === "user" ? `
      <div class="flex gap-3 justify-end" data-message-id="${messageId}">
        <div class="bg-primary text-white rounded-2xl rounded-tr-sm px-4 py-3 max-w-md">
          <p class="text-sm leading-relaxed">${this.escapeHtml(content)}</p>
        </div>
        <div class="w-8 h-8 rounded-full bg-secondary/20 flex items-center justify-center flex-shrink-0">
          <%= lucide_icon "user", class: "w-4 h-4 text-secondary" %>
        </div>
      </div>
    ` : `
      <div class="flex gap-3" data-message-id="${messageId}">
        <div class="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
          <%= lucide_icon "bot", class: "w-4 h-4 text-primary" %>
        </div>
        <div class="bg-surface-elevated rounded-2xl rounded-tl-sm px-4 py-3 max-w-md">
          <p class="text-sm text-primary leading-relaxed whitespace-pre-wrap">${this.escapeHtml(content)}</p>
        </div>
      </div>
    `

    // Insert before welcome message if it exists
    const welcomeEl = this.messagesList.querySelector("[data-voice-chat-target='welcome']")
    const temp = document.createElement("div")
    temp.innerHTML = messageHTML
    const messageEl = temp.firstElementChild as HTMLElement

    if (welcomeEl) {
      this.messagesList.insertBefore(messageEl, welcomeEl)
    } else {
      this.messagesList.appendChild(messageEl)
    }

    // Scroll to bottom
    this.conversationContainer?.scrollTo({
      top: this.conversationContainer.scrollHeight,
      behavior: "smooth"
    })

    // Store message
    this.messages.push({
      id: messageId,
      role,
      content,
      timestamp: new Date()
    })
  }

  private showLoadingState(state: "transcribing" | "thinking" | "synthesizing"): void {
    this.loadingStates?.classList.remove("hidden")

    this.hideAllLoadingStates()

    switch (state) {
      case "transcribing":
        this.transcribingState?.classList.remove("hidden")
        this.setStatus("Listening...")
        break
      case "thinking":
        this.thinkingState?.classList.remove("hidden")
        this.setStatus("Claude is thinking...")
        break
      case "synthesizing":
        this.synthesizingState?.classList.remove("hidden")
        this.setStatus("Speaking...")
        break
    }
  }

  private hideAllLoadingStates(): void {
    this.transcribingState?.classList.add("hidden")
    this.thinkingState?.classList.add("hidden")
    this.synthesizingState?.classList.add("hidden")
    this.loadingStates?.classList.add("hidden")
  }

  private setStatus(text: string): void {
    const statusEl = document.getElementById("connection-status")
    if (statusEl) {
      statusEl.textContent = text
    }
  }

  private showError(message: string): void {
    this.setStatus("Error")
    // Could add toast notification here
    console.error("[VoiceChat]", message)
  }

  private getCSRFToken(): string {
    const token = document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement
    return token?.content || ""
  }

  private escapeHtml(text: string): string {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  // ActionCable handlers for voice_chat_channel broadcasts
  protected handleConversationCreated(data: { conversation_id: number; message: string }): void {
    console.log("[VoiceChat] Conversation created:", data)
    this.setStatus("Processing voice...")
  }

  protected handleError(data: { error: string }): void {
    console.error("[VoiceChat] Error received:", data.error)
    this.showError(data.error)
  }
}
