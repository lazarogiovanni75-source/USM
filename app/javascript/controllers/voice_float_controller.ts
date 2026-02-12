import { Controller } from "@hotwired/stimulus"

// Voice streaming event interface for ActionCable messages
interface VoiceStreamEvent {
  type: 'chunk' | 'complete' | 'error'
  chunk?: string
  content?: string
  error?: string
  conversation_id?: number
}

// WAV encoder using Web Audio API - generates proper WAV files
class WAVEncoder {
  samples: Float32Array[] = []
  sampleRate: number = 48000
  numChannels: number = 1

  addChannelData(channelData: Float32Array): void {
    this.samples.push(new Float32Array(channelData))
  }

  encode(): Blob {
    const totalSamples = this.samples.reduce((sum, s) => sum + s.length, 0)
    const interleaved = new Float32Array(totalSamples)
    let offset = 0
    for (const channel of this.samples) {
      interleaved.set(channel, offset)
      offset += channel.length
    }

    const bytesPerSample = 2
    const blockAlign = this.numChannels * bytesPerSample
    const byteRate = this.sampleRate * blockAlign
    const dataSize = totalSamples * bytesPerSample
    const fileSize = 44 + dataSize

    const buffer = new ArrayBuffer(fileSize)
    const view = new DataView(buffer)

    this.writeString(view, 0, "RIFF")
    view.setUint32(4, fileSize - 8, true)
    this.writeString(view, 8, "WAVE")
    this.writeString(view, 12, "fmt ")
    view.setUint32(16, 16, true)
    view.setUint16(20, 1, true)
    view.setUint16(22, this.numChannels, true)
    view.setUint32(24, this.sampleRate, true)
    view.setUint32(28, byteRate, true)
    view.setUint16(32, blockAlign, true)
    view.setUint16(34, 16, true)
    this.writeString(view, 36, "data")
    view.setUint32(40, dataSize, true)

    let pos = 44
    for (let i = 0; i < interleaved.length; i++) {
      const sample = Math.max(-1, Math.min(1, interleaved[i]))
      const intSample = sample < 0 ? sample * 0x8000 : sample * 0x7FFF
      view.setInt16(pos, intSample, true)
      pos += 2
    }

    return new Blob([buffer], { type: "audio/wav" })
  }

  private writeString(view: DataView, offset: number, str: string): void {
    for (let i = 0; i < str.length; i++) {
      view.setUint8(offset + i, str.charCodeAt(i))
    }
  }

  reset(): void {
    this.samples = []
  }
}

// Voice Float Controller - Handles the floating AI voice button with streaming
export default class VoiceFloatController extends Controller {
  private modalElement: HTMLElement | null = null
  private isListening: boolean = false
  private channel: any = null
  private currentTranscript: string = ""
  private audioContext: AudioContext | null = null
  private mediaStream: MediaStream | null = null
  private analyser: AnalyserNode | null = null
  private processor: ScriptProcessorNode | null = null
  private wavEncoder: WAVEncoder | null = null
  private recordingStartTime: number = 0
  private recordingInterval: ReturnType<typeof setInterval> | null = null
  private wakePhrase: string = "hey Otto"
  private processingAudio: boolean = false
  private wakeWordEnabled: boolean = false

  // Streaming state
  private streamChannelName: string | null = null
  private currentConversationId: number | null = null
  private streamingResponse: string = ""
  private currentUserId: number | null = null

  connect(): void {
    console.log("[VoiceFloat] Controller connected")
    this.loadWakeWordSettings()
    this.loadUserId()
    this.ensureModalStructure()
  }

  private loadUserId(): void {
    const userIdMeta = document.querySelector('meta[name="user-id"]')
    if (userIdMeta) {
      const userId = userIdMeta.getAttribute('content')
      this.currentUserId = userId && userId !== 'anonymous' ? parseInt(userId, 10) : null
      console.log(`[VoiceFloat] User ID loaded: ${this.currentUserId}`)
    }
  }

  disconnect(): void {
    console.log("[VoiceFloat] Controller disconnected")
    this.stopListening()
  }

  private loadWakeWordSettings(): void {
    const savedPhrase = localStorage.getItem("wake_phrase")
    if (savedPhrase) {
      this.wakePhrase = savedPhrase.toLowerCase()
    }
    const wakeEnabled = localStorage.getItem("wake_word_enabled")
    this.wakeWordEnabled = wakeEnabled === "true"
    console.log(`[VoiceFloat] Wake word settings: phrase="${this.wakePhrase}", enabled=${this.wakeWordEnabled}`)
  }

  toggle(event?: Event): void {
    event?.preventDefault()
    console.log("[VoiceFloat] Toggle called, isListening=", this.isListening)
    if (this.isListening) {
      this.stopListening()
      this.closeModal()
    } else {
      this.openModal()
    }
  }

  openModal(): void {
    console.log("[VoiceFloat] Opening modal")
    this.ensureModalStructure()

    if (this.modalElement) {
      this.modalElement.classList.remove("hidden")
      this.modalElement.classList.add("flex")
    } else {
      console.error("[VoiceFloat] Modal element is null!")
    }

    setTimeout(() => {
      this.startWebAudioRecording()
    }, 500)
  }

  closeModal(): void {
    console.log("[VoiceFloat] Closing modal")
    this.stopListening()
    if (this.channel) {
      this.channel.unsubscribe()
      this.channel = null
    }
    if (this.modalElement) {
      this.modalElement.classList.add("hidden")
      this.modalElement.classList.remove("flex")
    }
  }

  private initializeActionCable(): void {
    if (!(window as any).ActionCable) {
      console.error("[VoiceFloat] ActionCable not available")
      return
    }

    if (this.channel) {
      console.log("[VoiceFloat] Channel already exists, reusing")
      return
    }

    // Use the stream_name from server response
    const streamName = this.streamChannelName || `voice_chat_${this.currentUserId || 0}`
    
    console.log(`[VoiceFloat] Subscribing to ActionCable stream: ${streamName}`)
    console.log("[VoiceFloat] Channel will receive messages on this stream")

    this.channel = (window as any).ActionCable.createConsumer().subscriptions.create(
      { channel: "VoiceChatChannel", stream_name: streamName },
      {
        connected: () => {
          console.log("[VoiceFloat] ✅ Streaming channel connected to:", streamName)
        },
        disconnected: () => {
          console.log("[VoiceFloat] ❌ Streaming channel disconnected")
        },
        received: (data: VoiceStreamEvent) => {
          console.log("[VoiceFloat] 📨 Raw message received from ActionCable:", data)
          this.handleStreamMessage(data)
        }
      }
    )
  }

  private handleStreamMessage(data: VoiceStreamEvent): void {
    console.log("[VoiceFloat] Stream message received. Type:", data.type, "Full data:", data)

    switch (data.type) {
      case 'chunk':
        console.log("[VoiceFloat] Processing chunk:", data.chunk)
        this.handleStreamingChunk(data.chunk || '')
        break
      case 'complete':
        console.log("[VoiceFloat] Processing complete:", data.content)
        this.handleStreamComplete(data.content || '')
        break
      case 'error':
        console.log("[VoiceFloat] Processing error:", data.error)
        this.handleStreamError(data.error || 'Unknown error')
        break
      default:
        console.warn("[VoiceFloat] Unknown message type:", data.type, data)
    }
  }

  private handleStreamingChunk(chunk: string): void {
    console.log("[VoiceFloat] Adding chunk. Before length:", this.streamingResponse.length, "Chunk:", chunk)
    this.streamingResponse += chunk
    console.log("[VoiceFloat] After length:", this.streamingResponse.length, "Full response:", this.streamingResponse)
    this.showStreamingResponse(this.streamingResponse)
  }

  private handleStreamComplete(content: string): void {
    console.log("[VoiceFloat] Stream complete, total length:", content.length)
    this.hideLoading()
    this.streamingResponse = ""
  }

  private handleStreamError(error: string): void {
    console.error(`[VoiceFloat] Stream error: ${error}`)
    this.hideLoading()
    this.updateTranscript(`Error: ${error}`)
    this.streamingResponse = ""
  }

  private async startWebAudioRecording(): Promise<void> {
    try {
      console.log("[VoiceFloat] Requesting microphone access")
      this.updateTranscript("Accessing microphone...")

      this.mediaStream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          channelCount: 1,
          sampleRate: 48000
        }
      })

      console.log("[VoiceFloat] Microphone access granted")
      this.updateConnectionStatus("connected", "Ready")
      this.updateTranscript("Listening... Speak now!")
      this.isListening = true

      this.audioContext = new AudioContext({ sampleRate: 48000 })
      const source = this.audioContext.createMediaStreamSource(this.mediaStream)

      this.analyser = this.audioContext.createAnalyser()
      this.analyser.fftSize = 256
      source.connect(this.analyser)

      this.processor = this.audioContext.createScriptProcessor(4096, 1, 1)
      this.wavEncoder = new WAVEncoder()
      this.wavEncoder.sampleRate = this.audioContext.sampleRate

      this.processor.onaudioprocess = (e) => {
        if (!this.isListening) return
        const inputData = e.inputBuffer.getChannelData(0)
        this.wavEncoder?.addChannelData(inputData)
      }

      source.connect(this.processor)
      this.processor.connect(this.audioContext.destination)

      this.recordingStartTime = Date.now()
      this.recordingInterval = setInterval(() => {
        this.checkRecordingDuration()
      }, 1000)

    } catch (error) {
      console.error("[VoiceFloat] Microphone error:", error)
      this.updateConnectionStatus("error", "Microphone access denied")
    }
  }

  private checkRecordingDuration(): void {
    if (!this.isListening) return

    const duration = Date.now() - this.recordingStartTime

    if (duration > 15000) {
      console.log("[VoiceFloat] Processing after 15 seconds of speech")
      this.processWavAudio()
    }
  }

  private processWavAudio(): void {
    if (!this.wavEncoder || this.processingAudio) return

    if (this.recordingInterval) {
      clearInterval(this.recordingInterval)
      this.recordingInterval = null
    }

    this.processingAudio = true
    const samplesLength = this.wavEncoder.samples.length
    console.log(`[VoiceFloat] Processing ${samplesLength} audio chunks`)

    if (samplesLength > 0) {
      this.sendForStreamingTranscription(this.wavEncoder.encode())
    } else {
      this.processingAudio = false
      this.restartListening()
    }
  }

  private sendForStreamingTranscription(audioBlob: Blob): void {
    console.log(`[VoiceFloat] Sending ${audioBlob.size} bytes for streaming transcription`)

    const formData = new FormData()
    formData.append("audio", audioBlob, "audio.wav")
    formData.append("detect_wake_word", this.wakeWordEnabled.toString())
    formData.append("conversation_id", this.currentConversationId?.toString() || "")

    this.updateTranscript("Transcribing...")
    this.showLoading()

    fetch("/api/v1/voice/stream", {
      method: "POST",
      body: formData
    })
      .then(response => {
        if (!response.ok) {
          return response.text().then(text => {
            throw new Error(`Transcription failed: ${response.status} - ${text}`)
          })
        }
        return response.json()
      })
      .then(data => {
        if (data.error) {
          console.error("[VoiceFloat] Server error:", data.error)
          this.hideLoading()
          this.processingAudio = false
          this.restartListening()
          return
        }

        console.log("[VoiceFloat] Streaming response:", data)

        // Set up streaming channel
        if (data.stream_name) {
          this.streamChannelName = data.stream_name
          this.currentConversationId = data.conversation_id
          this.initializeActionCable()
        }

        if (data.text && data.text.trim().length > 0) {
          this.updateTranscript(data.text)
        }

        this.processingAudio = false
      })
      .catch(error => {
        console.error("[VoiceFloat] Transcription error:", error)
        this.hideLoading()
        this.processingAudio = false
        this.restartListening()
      })
  }

  private stopListening(): void {
    console.log("[VoiceFloat] Stopping listening")
    this.isListening = false

    if (this.recordingInterval) {
      clearInterval(this.recordingInterval)
      this.recordingInterval = null
    }

    if (this.wavEncoder && this.wavEncoder.samples.length > 0 && this.modalElement && !this.modalElement.classList.contains("hidden")) {
      this.sendForStreamingTranscription(this.wavEncoder.encode())
    }

    if (this.processor) {
      this.processor.disconnect()
      this.processor = null
    }

    if (this.analyser) {
      this.analyser.disconnect()
      this.analyser = null
    }

    if (this.audioContext && this.audioContext.state !== "closed") {
      this.audioContext.close()
      this.audioContext = null
    }

    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach(track => track.stop())
      this.mediaStream = null
    }

    this.wavEncoder = null
  }

  private restartListening(): void {
    console.log("[VoiceFloat] Restarting listening for next command")

    this.processingAudio = false
    this.recordingStartTime = Date.now()
    this.streamingResponse = ""

    if (this.wavEncoder) {
      this.wavEncoder.reset()
      this.wavEncoder.sampleRate = this.audioContext?.sampleRate || 48000
    } else {
      this.wavEncoder = new WAVEncoder()
      this.wavEncoder.sampleRate = this.audioContext?.sampleRate || 48000
    }

    if (this.recordingInterval) {
      clearInterval(this.recordingInterval)
    }
    this.recordingInterval = setInterval(() => {
      this.checkRecordingDuration()
    }, 1000)

    this.isListening = true
    this.updateConnectionStatus("connected", "Ready")
    this.updateTranscript("Listening... Speak now!")
  }

  private updateTranscript(text: string): void {
    const el = document.getElementById("voice-transcript")
    if (el) {
      el.textContent = text
      console.log("[VoiceFloat] Updated transcript to:", text)
    } else {
      console.error("[VoiceFloat] Could not find voice-transcript element!")
    }
    this.currentTranscript = text
  }

  private updateConnectionStatus(status: string, message: string): void {
    const el = document.getElementById("voice-connection-status")
    if (el) {
      el.textContent = message
      el.className = `connection-status ${status}`
    }
  }

  private showLoading(): void {
    const el = document.getElementById("voice-loading")
    if (el) el.classList.remove("hidden")
  }

  private hideLoading(): void {
    const el = document.getElementById("voice-loading")
    if (el) el.classList.add("hidden")
  }

  private showStreamingResponse(text: string): void {
    console.log("[VoiceFloat] showStreamingResponse called. Text length:", text.length)
    console.log("[VoiceFloat] Text content:", text)
    const el = document.getElementById("voice-ai-response")
    console.log("[VoiceFloat] Element found:", !!el, "Element:", el)
    if (el) {
      el.innerHTML = text.replace(/\n/g, "<br>")
      el.classList.remove("hidden")
      console.log("[VoiceFloat] ✅ Element updated! Classes:", el.className, "innerHTML length:", el.innerHTML.length)
    } else {
      console.error("[VoiceFloat] ❌ ERROR: voice-ai-response element NOT FOUND in DOM!")
    }
  }

  private ensureModalStructure(): void {
    console.log("[VoiceFloat] Ensuring modal structure")

    const existingModal = document.getElementById("voice-modal")
    if (existingModal) {
      console.log("[VoiceFloat] Modal already exists")
      this.modalElement = existingModal as HTMLElement
      return
    }

    console.log("[VoiceFloat] Creating new modal")

    const modal = document.createElement("div")
    modal.id = "voice-modal"
    modal.className = "hidden fixed inset-0 bg-black/50 z-50 items-center justify-center p-4"
    modal.innerHTML = `
      <div class="bg-white dark:bg-gray-800 rounded-2xl p-6 w-full max-w-md mx-4 shadow-2xl">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold text-gray-900 dark:text-white">AI Voice Assistant</h3>
          <button id="voice-close-btn" class="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        
        <!-- Wake Word Toggle -->
        <div class="flex items-center justify-between mb-4 p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
          <div class="flex items-center space-x-3">
            <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
            </svg>
            <div>
              <p class="text-sm font-medium text-gray-900 dark:text-white">Wake Word</p>
              <p class="text-xs text-gray-500 dark:text-gray-400">Say "${this.wakePhrase}" to activate</p>
            </div>
          </div>
          <label class="relative inline-flex items-center cursor-pointer">
            <input type="checkbox" id="wake-word-toggle" class="sr-only peer"
              ${this.wakeWordEnabled ? 'checked' : ''}>
            <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4
              peer-focus:ring-purple-300 rounded-full peer peer-checked:after:translate-x-full
              peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px]
              after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full
              after:h-5 after:w-5 after:transition-all peer-checked:bg-purple-600"></div>
          </label>
        </div>
        
        <div id="voice-connection-status" class="connection-status idle text-sm text-gray-500 mb-4">
          Connecting...
        </div>
        <div class="flex flex-col items-center justify-center py-4">
          <div id="voice-transcript" class="text-lg text-gray-700 dark:text-gray-300 text-center min-h-[3rem] mb-4 w-full font-medium">
            Initializing...
          </div>
          <div id="voice-loading" class="hidden flex items-center justify-center">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
          </div>
          <div id="voice-ai-response" class="hidden mt-4 p-4 bg-green-50 dark:bg-green-900/30 border
            border-green-200 dark:border-green-700 rounded-lg text-sm
            text-gray-700 dark:text-gray-300 w-full text-left">
          </div>
          <div id="voice-result" class="hidden mt-4 p-3 bg-gray-100 dark:bg-gray-700 rounded-lg text-sm w-full"></div>
        </div>
      </div>
    `

    document.body.appendChild(modal)

    const closeBtn = document.getElementById("voice-close-btn")
    closeBtn?.addEventListener("click", () => this.closeModal())

    // Wake word toggle handler
    const wakeToggle = document.getElementById("wake-word-toggle")
    wakeToggle?.addEventListener("change", (e) => {
      const target = e.target as HTMLInputElement
      this.wakeWordEnabled = target.checked
      localStorage.setItem("wake_word_enabled", this.wakeWordEnabled.toString())
      console.log(`[VoiceFloat] Wake word ${this.wakeWordEnabled ? "enabled" : "disabled"}`)
    })

    modal.addEventListener("click", (e) => {
      if (e.target === modal) this.closeModal()
    })

    this.modalElement = modal
  }
}
