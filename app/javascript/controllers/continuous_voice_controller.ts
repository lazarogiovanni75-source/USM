import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

// ChatGPT-style continuous voice controller
// Uses MediaRecorder to capture continuous audio, sends to backend for transcription
// Implements early GPT trigger on pause detection (>700ms of silence)

interface VoiceEvent {
  type: string
  text?: string
  ai_response?: string
  wake_word_detected?: boolean
  error?: string
}

export default class extends Controller<HTMLElement> {
  static targets = [
    "voiceButton",
    "status",
    "transcription",
    "response"
  ]

  static values = {
    userId: String,
    conversationId: String
  }

  declare readonly voiceButtonTarget: HTMLButtonElement
  declare readonly statusTarget: HTMLElement
  declare readonly transcriptionTarget: HTMLElement
  declare readonly responseTarget: HTMLElement
  declare readonly userIdValue: string
  declare readonly conversationIdValue: string

  private mediaRecorder: MediaRecorder | null = null
  private audioChunks: Blob[] = []
  private stream: MediaStream | null = null
  private isRecording = false
  private isProcessing = false
  private audioContext: AudioContext | null = null
  private analyser: AnalyserNode | null = null
  private cableSubscription: any = null
  
  // Pause detection for early GPT trigger
  private lastAudioTime = 0
  private silenceTimer: ReturnType<typeof setTimeout> | null = null
  private silenceThreshold = 700 // ms of silence before triggering
  private minChunkDuration = 300 // minimum ms of audio before sending
  private pendingAudio: Blob[] = []
  private isTranscribing = false

  connect(): void {
    console.log("ContinuousVoice controller connected")
    this.updateStatus("Click microphone to start", "idle")
    this.subscribeToCable()
  }

  disconnect(): void {
    this.stopRecording()
    this.cableSubscription?.unsubscribe()
  }

  private subscribeToCable(): void {
    const streamName = `voice_interaction_${this.userIdValue}`
    this.cableSubscription = consumer.subscriptions.create(streamName, {
      received: (data: any) => {
        this.handleCableMessage(data)
      }
    })
    console.log("Subscribed to voice channel:", streamName)
  }

  private handleCableMessage(data: any): void {
    switch (data.type) {
      case 'chunk':
        // Handle streaming text response
        this.appendToResponse(data.content || '')
        break
      case 'complete':
        // Handle final response
        this.finishResponse(data.response || data.content || '')
        break
      case 'command-received':
        this.updateStatus("Processing...", "processing")
        break
      case 'error':
        this.updateStatus(`Error: ${data.error}`, "error")
        break
      case 'status-update':
        this.updateStatus(data.status || 'Processing...', 'processing')
        break
    }
  }

  private appendToResponse(text: string): void {
    const responseEl = this.responseTarget.querySelector('.response-content')
    if (responseEl) {
      responseEl.textContent += text
    }
  }

  private finishResponse(text: string): void {
    this.responseTarget.innerHTML = `
      <div class="response-content p-4 bg-blue-50 rounded-lg">
        <div class="text-gray-800">${text}</div>
      </div>
    `
    this.updateStatus("🎙️ Listening...", "listening")
  }

  async toggleRecording() {
    if (this.isRecording) {
      this.stopRecording()
    } else {
      await this.startRecording()
    }
  }

  async startRecording() {
    try {
      // Get microphone access
      this.stream = await navigator.mediaDevices.getUserMedia({ 
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        } 
      })

      // Set up audio analysis for visual feedback
      this.audioContext = new AudioContext()
      this.analyser = this.audioContext.createAnalyser()
      const source = this.audioContext.createMediaStreamSource(this.stream)
      source.connect(this.analyser)

      // Create MediaRecorder for continuous recording
      this.mediaRecorder = new MediaRecorder(this.stream, {
        mimeType: 'audio/webm;codecs=opus'
      })

      this.audioChunks = []

      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.audioChunks.push(event.data)
          this.lastAudioTime = Date.now()
          
          // Check if we should send for early processing
          this.checkForSilence()
        }
      }

      this.mediaRecorder.onstop = () => {
        this.processAudio()
      }

      // Start recording with smaller time slices for better latency
      this.mediaRecorder.start(300) // Collect chunks every 300ms for near-real-time processing
      this.isRecording = true
      
      // Reset pause detection
      this.lastAudioTime = Date.now()
      this.pendingAudio = []
      
      this.updateStatus("🎙️ Listening...", "listening")
      this.voiceButtonTarget.classList.add('recording')
      
      console.log("Started continuous recording")
      
    } catch (error: any) {
      console.error("Failed to start recording:", error)
      this.updateStatus(`Error: ${error.message}`, "error")
    }
  }

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      this.mediaRecorder.stop()
    }
    
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
      this.stream = null
    }

    if (this.audioContext) {
      this.audioContext.close()
      this.audioContext = null
    }

    this.isRecording = false
    this.voiceButtonTarget.classList.remove('recording')
    this.updateStatus("Click to speak", "idle")
  }

  private checkForSilence(): void {
    // Clear existing timer
    if (this.silenceTimer) {
      clearTimeout(this.silenceTimer)
    }
    
    // Set timer to detect silence
    this.silenceTimer = setTimeout(() => {
      const silenceDuration = Date.now() - this.lastAudioTime
      
      // If we've had enough silence and have audio, process it
      if (silenceDuration >= this.silenceThreshold && this.audioChunks.length > 0) {
        this.processAudio(true) // true = early trigger
      }
    }, this.silenceThreshold)
  }

  private async processAudio(isEarlyTrigger = false) {
    // Don't process if already processing
    if (this.isProcessing || this.isTranscribing) {
      return
    }

    if (this.audioChunks.length === 0) {
      // Restart recording if we were recording
      if (this.isRecording) {
        setTimeout(() => this.startRecording(), 100)
      }
      return
    }

    this.isProcessing = true
    this.updateStatus("⏳ Processing...", "processing")

    // Combine audio chunks
    const audioBlob = new Blob(this.audioChunks, { type: 'audio/webm' })
    this.audioChunks = []
    this.pendingAudio = []

    try {
      // Send to backend for transcription
      const formData = new FormData()
      formData.append('audio', audioBlob, 'audio.webm')
      formData.append('detect_wake_word', 'false')
      formData.append('early_trigger', isEarlyTrigger.toString())
      formData.append('conversation_id', this.conversationIdValue || '')
      formData.append('stream_name', `voice_interaction_${this.userIdValue}`)

      const response = await fetch('/api/v1/voice/stream', {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': this.getCSRFToken()
        }
      })

      const data = await response.json()

      if (data.error) {
        this.updateStatus(`Error: ${data.error}`, "error")
      } else if (data.text) {
        // Show transcription
        this.transcriptionTarget.innerHTML = `
          <div class="text-lg font-medium text-gray-900">${data.text}</div>
        `

        // Clear previous response for new one
        this.responseTarget.innerHTML = ''

        // Status will be updated by ActionCable messages
        if (!data.stream_name) {
          // Fallback if no streaming
          if (data.ai_response) {
            this.responseTarget.innerHTML = `
              <div class="p-4 bg-blue-50 rounded-lg">
                <div class="text-gray-800">${data.ai_response}</div>
              </div>
            `
          }
          this.updateStatus("🎙️ Listening...", "listening")
        }
      } else {
        this.updateStatus("🎙️ Listening...", "listening")
      }

    } catch (error: any) {
      console.error("Transcription error:", error)
      this.updateStatus(`Error: ${error.message}`, "error")
    }

    this.isProcessing = false

    // Restart recording for continuous conversation
    if (this.isRecording) {
      setTimeout(() => this.startRecording(), 100)
    }
  }

  private updateStatus(message: string, status: string) {
    this.statusTarget.textContent = message
    this.statusTarget.className = `text-sm mt-2 ${
      status === 'listening' ? 'text-green-600' :
        status === 'processing' ? 'text-blue-600' :
          status === 'error' ? 'text-red-600' :
            'text-gray-500'
    }`
  }

  private getCSRFToken(): string {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') || '' : ''
  }
}
