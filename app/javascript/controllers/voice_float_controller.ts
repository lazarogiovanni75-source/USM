import { Controller } from "@hotwired/stimulus"

// VoiceCommandEvent interface for ActionCable messages
interface VoiceCommandEvent {
  type: string
  command_text?: string
  response_text?: string
  command_type?: string
  error?: string
  video?: any
  content?: any
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

// Voice Float Controller - Handles the floating AI voice button
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

  connect(): void {
    console.log("[VoiceFloat] Controller connected")
    this.loadWakeWordSettings()
    this.ensureModalStructure()
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

    this.initializeActionCable()

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
    this.updateConnectionStatus("connecting", "Connecting...")

    if (!(window as any).ActionCable) {
      console.error("[VoiceFloat] ActionCable not available")
      this.updateConnectionStatus("error", "ActionCable not available")
      return
    }

    // Don't create duplicate subscriptions
    if (this.channel) {
      console.log("[VoiceFloat] Channel already exists, reusing")
      this.updateConnectionStatus("connected", "Connected")
      return
    }

    this.channel = (window as any).ActionCable.createConsumer().subscriptions.create(
      { channel: "VoiceInteractionChannel", stream_name: "voice_interaction_demo" },
      {
        connected: () => {
          console.log("[VoiceFloat] Channel connected")
          this.updateConnectionStatus("connected", "Connected")
        },
        disconnected: () => {
          console.log("[VoiceFloat] Channel disconnected")
          this.updateConnectionStatus("error", "Disconnected")
        },
        received: (data: VoiceCommandEvent) => this.handleChannelMessage(data)
      }
    )
  }

  private handleChannelMessage(data: VoiceCommandEvent): void {
    console.log("[VoiceFloat] Received message:", data)

    switch (data.type) {
      case "command-completed":
        this.hideLoading()
        this.updateTranscript(data.response_text || "Command completed!")
        this.showResult(data.response_text || "Success!", data.command_type)
        break
      case "command-failed":
        this.hideLoading()
        break
      case "video-generated":
        this.hideLoading()
        this.updateTranscript("Video generated successfully!")
        this.showResult("Video created!", "video_generation", data.video)
        break
      case "content-generated":
        this.hideLoading()
        this.updateTranscript("Content generated successfully!")
        this.showResult("Content created!", "content_generation", data.content)
        break
    }
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
      this.updateTranscript('Listening... Say "Hey Otto"!')
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

    if (duration > 10000) {
      console.log("[VoiceFloat] Auto-stopping recording after 10 seconds")
      this.processWavAudio()
    }
  }

  private processWavAudio(): void {
    if (!this.wavEncoder || this.processingAudio) return

    this.processingAudio = true
    const samplesLength = this.wavEncoder.samples.length
    console.log(`[VoiceFloat] Processing ${samplesLength} audio chunks`)

    if (samplesLength > 0) {
      this.sendToWhisper(this.wavEncoder.encode())
    } else {
      this.processingAudio = false
    }
  }

  private sendToWhisper(audioBlob: Blob): void {
    console.log(`[VoiceFloat] Sending ${audioBlob.size} bytes to Whisper`)

    const formData = new FormData()
    formData.append("audio", audioBlob, "audio.wav")
    formData.append("detect_wake_word", "true")
    formData.append("wake_phrase", this.wakePhrase)

    this.updateTranscript("Transcribing...")
    this.showLoading()

    fetch("/api/v1/voice/transcribe", {
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
        this.hideLoading()
        this.processingAudio = false

        if (data.error) {
          console.error("[VoiceFloat] Server error:", data.error)
          this.restartListening()
          return
        }

        console.log("[VoiceFloat] Whisper transcribed:", data.text)
        console.log("[VoiceFloat] AI response:", data.ai_response)

        if (data.text && data.text.trim().length > 0) {
          this.updateTranscript(data.text)

          // Show AI response if available
          if (data.ai_response) {
            console.log("[VoiceFloat] Showing AI response:", data.ai_response)
            this.showAiResponse(data.ai_response)
          }
        }

        // Restart listening for next command
        this.restartListening()
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

    // Only process remaining audio if modal is still visible (not during cleanup)
    // This prevents infinite loops when closeModal() calls stopListening()
    if (this.wavEncoder && this.wavEncoder.samples.length > 0 && this.modalElement && !this.modalElement.classList.contains("hidden")) {
      this.sendToWhisper(this.wavEncoder.encode())
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

    // Reset recording state
    this.processingAudio = false
    this.recordingStartTime = Date.now()

    // Create fresh audio context and encoder
    if (!this.audioContext || this.audioContext.state === "closed") {
      this.audioContext = new AudioContext({ sampleRate: 48000 })
    }

    this.wavEncoder = new WAVEncoder()
    this.wavEncoder.sampleRate = this.audioContext.sampleRate

    // Reconnect audio nodes
    if (this.mediaStream) {
      const source = this.audioContext.createMediaStreamSource(this.mediaStream)
      this.analyser = this.audioContext.createAnalyser()
      this.analyser.fftSize = 256
      source.connect(this.analyser)

      this.processor = this.audioContext.createScriptProcessor(4096, 1, 1)
      this.processor.onaudioprocess = (e) => {
        if (!this.isListening) return
        const inputData = e.inputBuffer.getChannelData(0)
        this.wavEncoder?.addChannelData(inputData)
      }
      source.connect(this.processor)
      this.processor.connect(this.audioContext.destination)
    }

    // Start the recording interval again
    this.recordingInterval = setInterval(() => {
      this.checkRecordingDuration()
    }, 1000)

    this.isListening = true
    this.updateConnectionStatus("connected", "Ready")
    this.updateTranscript('Listening... Say "Hey Otto"!')
  }

  private onWakeWordDetected(): void {
    console.log("[VoiceFloat] Wake word detected!")
    this.updateTranscript("Wake word detected!")
  }

  private processCommand(text: string): void {
    console.log("[VoiceFloat] Processing command:", text)

    if (this.channel) {
      this.channel.send({
        type: "voice_command",
        command_text: text
      })
    }
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

  private showResult(message: string, type?: string, data?: any): void {
    const el = document.getElementById("voice-result")
    if (el) {
      el.textContent = message
      el.classList.remove("hidden")
    }
  }

  private showAiResponse(text: string): void {
    const el = document.getElementById("voice-ai-response")
    if (el) {
      el.innerHTML = text.replace(/\n/g, "<br>")
      el.classList.remove("hidden")
      console.log("[VoiceFloat] AI response shown:", text)
    } else {
      console.error("[VoiceFloat] Could not find voice-ai-response element!")
    }
  }

  private showDebugInfo(data: any): void {
    const debugEl = document.getElementById("voice-debug")
    if (debugEl) {
      debugEl.classList.remove("hidden")
      debugEl.innerHTML = `<pre class="text-xs overflow-auto max-h-32">${JSON.stringify(data, null, 2)}</pre>`
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
          <div id="voice-debug" class="hidden mt-4 p-4 bg-yellow-50 dark:bg-yellow-900/30 border
            border-yellow-200 dark:border-yellow-700 rounded-lg text-xs
            text-gray-700 dark:text-gray-300 w-full text-left font-mono">
          </div>
          <div id="voice-result" class="hidden mt-4 p-3 bg-gray-100 dark:bg-gray-700 rounded-lg text-sm w-full"></div>
        </div>
      </div>
    `

    document.body.appendChild(modal)

    const closeBtn = document.getElementById("voice-close-btn")
    closeBtn?.addEventListener("click", () => this.closeModal())

    modal.addEventListener("click", (e) => {
      if (e.target === modal) this.closeModal()
    })

    this.modalElement = modal
  }
}
