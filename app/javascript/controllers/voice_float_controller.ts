import { Controller } from "@hotwired/stimulus"

// Voice streaming event interface for ActionCable messages
interface VoiceStreamEvent {
  type: | 'chunk' 
        | 'complete' 
        | 'error' 
        | 'command-received' 
        | 'tool_call_detected' 
        | 'tool_execution_started' 
        | 'tool_execution_completed' 
        | 'tool_execution_failed' 
        | 'assistant_token' 
        | 'assistant_complete' 
        | 'awaiting_confirmation'
        | 'conversation_created'
        | 'processing'
  chunk?: string
  content?: string
  error?: string
  message?: string
  transcript?: string
  conversation_id?: number
  execution_id?: string
  payload?: {
    tool?: string
    arguments?: Record<string, any>
    result?: any
    error?: string
    requiresConfirmation?: boolean
    confirmed?: boolean
  }
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
  private channels: any[] = []  // Store all ActionCable subscriptions
  private currentTranscript: string = ""
  private audioContext: AudioContext | null = null
  private mediaStream: MediaStream | null = null
  private analyser: AnalyserNode | null = null
  private processor: ScriptProcessorNode | null = null
  private wavEncoder: WAVEncoder | null = null
  private recordingStartTime: number = 0
  private recordingInterval: ReturnType<typeof setInterval> | null = null
  private wakePhrase: string = "hey Pilot"
  private processingAudio: boolean = false
  private wakeWordEnabled: boolean = false
  private lastProcessedTime: number = 0
  private silenceStartTime: number = 0
  private isSpeaking: boolean = false

  // Streaming state
  private currentConversationId: number | null = null
  private streamingResponse: string = ""
  private currentUserId: number | null = null

  // Auto-restart listening after processing
  private autoRestartEnabled: boolean = true

  connect(): void {
    this.autoRestartEnabled = true
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
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    console.log('[VoiceFloat] Toggle called, isListening=', this.isListening)
    console.log('[VoiceFloat] Modal element before:', this.modalElement)
    
    if (this.isListening) {
      console.log('[VoiceFloat] Stopping listening')
      this.stopListening()
      this.closeModal()
    } else {
      console.log('[VoiceFloat] Starting listening')
      this.openModal()
    }
  }

  openModal(): void {
    console.log("[VoiceFloat] Opening modal - ensuring structure first")
    this.updateDebugStatus("Opening modal...")
    
    // Ensure modal structure exists BEFORE trying to open
    this.ensureModalStructure()
    this.updateDebugStatus("Modal created, showing...")
    
    // Modal should now exist after ensureModalStructure
    // (or it already existed from before)
    if (!this.modalElement) {
      console.error("[VoiceFloat] Modal element is STILL null after ensureModalStructure!")
      this.updateDebugStatus("ERROR: Modal not found!")
      // Try to find it directly in DOM as fallback
      this.modalElement = document.getElementById("voice-modal") as HTMLElement
    }
    
    if (!this.modalElement) {
      console.error("[VoiceFloat] Could not find or create modal at all!")
      this.updateDebugStatus("ERROR: Cannot create modal!")
      console.error("[VoiceFloat] Please refresh and try again")
      return
    }
    
    this.updateDebugStatus("Showing modal...")
    console.log("[VoiceFloat] Modal element found, showing it")
    this.modalElement.classList.remove("hidden")
    this.modalElement.classList.add("flex")

    // Subscribe to ActionCable channels BEFORE starting to listen
    console.log("[VoiceFloat] Initializing ActionCable...")
    this.updateDebugStatus("Connecting to server...")
    this.initializeActionCable()

    // Start recording after a short delay
    console.log("[VoiceFloat] Scheduling WebAudio recording in 500ms...")
    this.updateDebugStatus("Starting microphone...")
    setTimeout(() => {
      console.log("[VoiceFloat] Timeout fired, calling startWebAudioRecording...")
      this.startWebAudioRecording()
    }, 500)
  }

  closeModal(): void {
    console.log("[VoiceFloat] Closing modal")
    this.stopListening()
    // Clean up all ActionCable subscriptions
    this.channels.forEach(ch => {
      try { ch.unsubscribe() } catch(e) { /* ignore */ }
    })
    this.channels = []
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

    const userId = this.currentUserId || 0
    const voiceChannelName = `voice_chat_${userId}`
    const aiChannelName = `ai_chat_${userId}`
    console.log(`[VoiceFloat] Subscribing to channels: ${voiceChannelName}, ${aiChannelName}`)

    // Subscribe to voice_chat channel for voice processing responses
    if (!this.channel) {
      this.channel = (window as any).ActionCable.createConsumer().subscriptions.create(
        { channel: "VoiceChatChannel", stream_name: voiceChannelName },
        {
          connected: () => {
            console.log("[VoiceFloat] ✅ Voice channel connected:", voiceChannelName)
          },
          disconnected: () => {
            console.log("[VoiceFloat] ❌ Voice channel disconnected")
          },
          received: (data: VoiceStreamEvent) => {
            console.log("[VoiceFloat] 📬 Voice message received:", data.type)
            this.handleStreamMessage(data)
          }
        }
      )
    }

    // Also subscribe to ai_chat channel for AI response streaming
    // NOTE: Backend AiChatChannel looks for params[:conversation_id], not stream_name
    const aiConversationId = this.currentConversationId || 'new'
    const aiChannel = (window as any).ActionCable.createConsumer().subscriptions.create(
      { channel: "AiChatChannel", conversation_id: aiConversationId },
      {
        connected: () => {
          console.log(`[VoiceFloat] ✅ AI channel connected: ai_chat_${aiConversationId}`)
        },
        disconnected: () => {
          console.log("[VoiceFloat] ❌ AI channel disconnected")
        },
        received: (data: any) => {
          console.log("[VoiceFloat] 📬 AI Chat message received:", data.type || data)
          // Handle AI chat streaming events
          if (data.type === 'content_delta' || data.delta) {
            this.handleStreamingChunk(data.delta || data.content || '')
          } else if (data.type === 'completion' || data.full_content) {
            this.handleStreamComplete(data.full_content || data.content || '')
          } else if (data.type === 'processing') {
            this.showLoading()
            this.updateTranscript(data.message || 'AI is thinking...')
          }
        }
      }
    )
    this.channels.push(aiChannel)

    // Subscribe to conversation-specific channel (ai_chat_{conversation_id})
    // Backend AiChatChannel uses params[:conversation_id] to build stream name
    const convConversationId = this.currentConversationId || 'new'
    const convChannel = (window as any).ActionCable.createConsumer().subscriptions.create(
      { channel: "AiChatChannel", conversation_id: convConversationId },
      {
        connected: () => {
          console.log(`[VoiceFloat] ✅ Conversation channel connected: ai_chat_${convConversationId}`)
        },
        received: (data: any) => {
          console.log("[VoiceFloat] 📬 Conv channel message:", data.type || data)
          if (data.type === 'content_delta' || data.delta) {
            this.handleStreamingChunk(data.delta || data.content || '')
          } else if (data.type === 'completion' || data.full_content) {
            this.handleStreamComplete(data.full_content || data.content || '')
          } else if (data.type === 'processing') {
            this.showLoading()
            this.updateTranscript(data.message || 'AI is thinking...')
          }
        }
      }
    )
    this.channels.push(convChannel)
  }

  private handleStreamMessage(data: VoiceStreamEvent): void {
    console.log("[VoiceFloat] 📥 Message received:", data.type, "Full data:", JSON.stringify(data).substring(0, 200))

    switch (data.type) {
      case 'conversation_created':
        console.log("[VoiceFloat] Conversation created:", data.conversation_id)
        if (data.conversation_id) {
          this.currentConversationId = data.conversation_id
        }
        break
      case 'processing':
        console.log("[VoiceFloat] AI is processing:", data.message)
        this.showLoading()
        this.updateTranscript(data.message || 'AI is thinking...')
        break
      case 'command-received':
        console.log("[VoiceFloat] Command received:", data.message)
        this.handleCommandReceived(data.message || '')
        break
      case 'assistant_token':
      case 'chunk':
        console.log("[VoiceFloat] Processing chunk:", data.content || data.chunk)
        this.handleStreamingChunk(data.content || data.chunk || '')
        break
      case 'assistant_complete':
      case 'complete':
        console.log("[VoiceFloat] Processing complete, content:", data.content)
        this.handleStreamComplete(data.content || '')
        break
      case 'tool_call_detected':
        console.log("[VoiceFloat] Tool call detected:", data.payload?.tool)
        this.handleToolCallDetected(data.payload?.tool || '', data.payload?.arguments || {})
        break
      case 'tool_execution_started':
        console.log("[VoiceFloat] Tool execution started:", data.payload?.tool)
        this.handleToolExecutionStarted(data.payload?.tool || '')
        break
      case 'tool_execution_completed':
        console.log("[VoiceFloat] Tool execution completed:", data.payload?.tool, data.payload?.result)
        this.handleToolExecutionCompleted(data.payload?.tool || '', data.payload?.result)
        break
      case 'tool_execution_failed':
        console.log("[VoiceFloat] Tool execution failed:", data.payload?.error)
        this.handleToolExecutionFailed(data.payload?.tool || '', data.payload?.error || 'Unknown error')
        break
      case 'awaiting_confirmation':
        console.log("[VoiceFloat] Awaiting confirmation:", data.payload?.tool)
        this.handleAwaitingConfirmation(data.payload?.tool || '')
        break
      case 'error':
        console.log("[VoiceFloat] Processing error:", data.error)
        this.handleStreamError(data.error || 'Unknown error')
        break
      default:
        console.warn("[VoiceFloat] Unknown message type:", data.type, data)
    }
  }

  private handleCommandReceived(message: string): void {
    console.log("[VoiceFloat] Handling command received confirmation")
    // Show user's transcribed text in the chat UI (as user message)
    // But DON'T speak it back - the user already knows what they said
    const transcriptEl = document.getElementById('voice-transcript')
    if (transcriptEl) {
      transcriptEl.textContent = ""
    }
  }

  private handleStreamingChunk(chunk: string): void {
    console.log("[VoiceFloat] Adding chunk. Before length:", this.streamingResponse.length, "Chunk:", chunk)
    this.streamingResponse += chunk
    console.log("[VoiceFloat] After length:", this.streamingResponse.length, "Full response:", this.streamingResponse)
    this.showStreamingResponse(this.streamingResponse)
  }

  private handleStreamComplete(content: string): void {
    console.log("[VoiceFloat] Stream complete, content length:", content.length, "Content:", content)
    this.hideLoading()
    this.streamingResponse = ""
    
    // Show the response in the UI
    if (content && content.trim().length > 0) {
      this.showStreamingResponse(content)
      // Speak the AI response - this is the main voice output
      this.speakResponse(content)
    } else {
      console.log("[VoiceFloat] No content to speak, restarting listening")
      // If no content, just restart listening
      this.restartListening()
    }
  }

  private handleStreamError(error: string): void {
    console.error(`[VoiceFloat] Stream error: ${error}`)
    this.hideLoading()
    this.updateTranscript(`Error: ${error}`)
    this.streamingResponse = ""
  }

  // Tool execution handlers
  private handleToolCallDetected(tool: string, args: Record<string, any>): void {
    console.log(`[VoiceFloat] Tool detected: ${tool}`, args)
    this.showToolExecutionStatus(`Executing: ${tool}...`)
  }

  private handleToolExecutionStarted(tool: string): void {
    console.log(`[VoiceFloat] Tool started: ${tool}`)
    this.showToolExecutionStatus(`Running ${tool}...`)
    // Stop any current speech when tool starts
    window.speechSynthesis?.cancel()
  }

  private handleToolExecutionCompleted(tool: string, result: any): void {
    console.log(`[VoiceFloat] Tool completed: ${tool}`, result)
    this.hideLoading()
    
    let message = `Completed: ${tool}`
    if (result?.message) {
      message = result.message
    } else if (result?.status === 'success') {
      message = `${tool} executed successfully!`
    }
    this.showToolExecutionStatus(message)
    
    // Speak the result
    this.speakResponse(message)
    // After speaking, the onend callback will restart listening
  }

  private handleToolExecutionFailed(tool: string, error: string): void {
    console.log(`[VoiceFloat] Tool failed: ${tool}`, error)
    this.hideLoading()
    const message = `Failed to execute ${tool}: ${error}`
    this.showToolExecutionStatus(message)
    this.speakResponse(message)
    // After speaking, the onend callback will restart listening
  }

  private handleAwaitingConfirmation(tool: string): void {
    console.log(`[VoiceFloat] Awaiting confirmation for: ${tool}`)
    this.showToolExecutionStatus(`Please confirm: ${tool}`)
    this.speakResponse(`Do you want me to ${tool}? Please say yes or no.`)
  }

  private showToolExecutionStatus(message: string): void {
    const statusEl = document.getElementById('voice-status')
    if (statusEl) {
      statusEl.textContent = message
      statusEl.classList.add('text-orange-600')
    }
  }

  private async startWebAudioRecording(): Promise<void> {
    console.log("[VoiceFloat] startWebAudioRecording called")
    this.updateDebugStatus("Requesting microphone...")
    try {
      console.log("[VoiceFloat] Requesting microphone access via navigator.mediaDevices.getUserMedia")
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

      console.log("[VoiceFloat] Microphone access GRANTED, mediaStream:", this.mediaStream?.id)
      this.updateDebugStatus("Mic granted, setting up audio...")
      this.updateConnectionStatus("connected", "Ready")
      this.updateTranscript("Listening... Speak now!")
      this.isListening = true

      console.log("[VoiceFloat] Creating AudioContext with sampleRate: 48000")
      this.updateDebugStatus("AudioContext created, starting recording...")
      this.audioContext = new AudioContext({ sampleRate: 48000 })
      const source = this.audioContext.createMediaStreamSource(this.mediaStream)

      this.analyser = this.audioContext.createAnalyser()
      this.analyser.fftSize = 256
      source.connect(this.analyser)

      this.processor = this.audioContext.createScriptProcessor(4096, 1, 1)
      this.wavEncoder = new WAVEncoder()
      this.wavEncoder.sampleRate = this.audioContext.sampleRate

      console.log("[VoiceFloat] Setting up audio processor")
      this.processor.onaudioprocess = (e) => {
        if (!this.isListening) return
        const inputData = e.inputBuffer.getChannelData(0)
        this.wavEncoder?.addChannelData(inputData)
      }

      source.connect(this.processor)
      this.processor.connect(this.audioContext.destination)

      this.recordingStartTime = Date.now()
      this.lastProcessedTime = Date.now()
      this.silenceStartTime = 0
      this.isSpeaking = false
      
      console.log("[VoiceFloat] Starting recording interval")
      this.recordingInterval = setInterval(() => {
        this.checkRecordingDuration()
        this.checkForSilence()
      }, 100) // Check every 100ms for better responsiveness

    } catch (error) {
      console.error("[VoiceFloat] Microphone error:", error)
      console.error("[VoiceFloat] Error name:", (error as Error).name)
      console.error("[VoiceFloat] Error message:", (error as Error).message)
      this.updateDebugStatus(`ERROR: ${(error as Error).message || 'Mic denied'}`)
      this.updateConnectionStatus("error", "Microphone access denied")
      this.updateTranscript(`Error: ${(error as Error).message || 'Microphone access denied'}`)
    }
  }

  private checkRecordingDuration(): void {
    if (!this.isListening) return

    const duration = Date.now() - this.recordingStartTime

    // Auto-process after 30 seconds of recording
    if (duration > 30000) {
      console.log("[VoiceFloat] Processing after 20 seconds of speech")
      this.processWavAudio()
    }
  }

  // Check for silence/voice activity to stop recording earlier
  private checkForSilence(): void {
    if (!this.isListening || !this.analyser) return

    const dataArray = new Uint8Array(this.analyser.frequencyBinCount)
    this.analyser.getByteFrequencyData(dataArray)

    // Calculate average volume
    const average = dataArray.reduce((a, b) => a + b) / dataArray.length
    const threshold = 15 // Silence threshold

    const duration = Date.now() - this.recordingStartTime

    // Only process after minimum 4 seconds of audio
    if (duration < 4000) {
      return
    }

    if (average > threshold) {
      // User is speaking
      this.isSpeaking = true
      this.silenceStartTime = 0
    } else {
      // Silence detected
      if (this.isSpeaking && this.silenceStartTime === 0) {
        // User just stopped speaking
        this.silenceStartTime = Date.now()
      }

      // If we've had 4 seconds of silence after speech, process the audio
      if (this.silenceStartTime > 0 && Date.now() - this.silenceStartTime > 4000) {
        console.log("[VoiceFloat] Detected end of speech (4s silence), processing audio")
        this.processWavAudio()
      }
    }
  }

  private processWavAudio(): void {
    if (!this.wavEncoder || this.processingAudio) return

    // Prevent duplicate processing within 3 seconds
    const timeSinceLastProcess = Date.now() - this.lastProcessedTime
    if (timeSinceLastProcess < 3000) {
      console.log(`[VoiceFloat] Skipping duplicate processing (${timeSinceLastProcess}ms since last)`)  
      return
    }

    if (this.recordingInterval) {
      clearInterval(this.recordingInterval)
      this.recordingInterval = null
    }

    this.processingAudio = true
    this.lastProcessedTime = Date.now()
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

        // Update conversation ID if provided
        if (data.conversation_id) {
          this.currentConversationId = data.conversation_id
          console.log("[VoiceFloat] Updated conversation ID to:", this.currentConversationId)
        }

        // Show user transcript (but DON'T clear AI response - keep it visible)
        if (data.text && data.text.trim().length > 0) {
          // Show user's input
          this.updateTranscript(`You: ${data.text}`)
        }

        this.processingAudio = false
      })
      .catch(error => {
        console.error("[VoiceFloat] Transcription error:", error)
        this.hideLoading()
        this.processingAudio = false
        // Restart listening on error too
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

    // Don't process audio here - this is called during restart too
    // Just clean up resources

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
    this.lastProcessedTime = Date.now()
    this.silenceStartTime = 0
    this.isSpeaking = false
    this.streamingResponse = ""

    // Clean up old audio resources if they exist
    this.stopListening()

    // Start fresh recording
    setTimeout(() => {
      this.startWebAudioRecording()
    }, 300)
  }

  // Text-to-Speech: Speak the AI response
  // Strip emojis and problematic characters before speaking
  private stripEmojis(text: string): string {
    // Remove emojis and problematic Unicode characters
    const emojiRegex = /[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}]/gu
    return text.replace(emojiRegex, '').trim()
  }

  private async speakResponse(text: string): Promise<void> {
    console.log("[VoiceFloat] speakResponse called with:", text.substring(0, 100))
    
    if (!('speechSynthesis' in window)) {
      console.log("[VoiceFloat] Text-to-speech not supported in this browser")
      this.updateTranscript("TTS not supported")
      this.restartListening()
      return
    }

    // Cancel any ongoing speech
    window.speechSynthesis.cancel()

    // Strip emojis and problematic characters before speaking
    const cleanText = this.stripEmojis(text)
    
    if (!cleanText || cleanText.length === 0) {
      console.log("[VoiceFloat] No text to speak after removing emojis")
      this.updateTranscript("No response to speak")
      this.restartListening()
      return
    }

    console.log("[VoiceFloat] Speaking clean text:", cleanText.substring(0, 50))

    const utterance = new SpeechSynthesisUtterance(cleanText)
    utterance.lang = 'en-US'
    utterance.rate = 1.0
    utterance.pitch = 1.0
    
    // Try to select a male voice
    const voices = window.speechSynthesis.getVoices()
    console.log("[VoiceFloat] Available voices:", voices.length)
    const maleVoice = voices.find((v: any) => 
      v.name.includes('Male') || 
      v.name.includes('David') || 
      v.name.includes('Mark') || 
      v.name.includes('James') ||
      v.name.includes('John') ||
      v.name.includes('Paul')
    )
    if (maleVoice) {
      utterance.voice = maleVoice
      console.log("[VoiceFloat] Using male voice:", maleVoice.name)
    } else {
      // Fallback to any English voice
      const englishVoice = voices.find((v: any) => v.lang.startsWith('en'))
      if (englishVoice) {
        utterance.voice = englishVoice
        console.log("[VoiceFloat] Using English voice:", englishVoice.name)
      }
    }

    utterance.onend = () => {
      console.log("[VoiceFloat] Speech complete, restarting listening")
      this.updateTranscript("Listening... Speak now!")
      if (this.autoRestartEnabled) {
        setTimeout(() => this.restartListening(), 500)
      }
    }

    utterance.onerror = (e) => {
      console.error("[VoiceFloat] Speech error:", e.error)
      this.updateTranscript("Speech error, try again")
      if (this.autoRestartEnabled) {
        this.restartListening()
      }
    }

    console.log("[VoiceFloat] Calling window.speechSynthesis.speak()")
    try {
      window.speechSynthesis.speak(utterance)
      console.log("[VoiceFloat] speak() called successfully")
    } catch (e) {
      console.error("[VoiceFloat] Exception during speak():", e)
      this.updateTranscript("Speech error")
      this.restartListening()
    }
  }

  private updateTranscript(text: string): void {
    const el = document.getElementById("voice-transcript")
    if (el) {
      el.textContent = text
      console.log("[VoiceFloat] Updated transcript to:", text)
    } else {
      // Fallback: try to find transcript in modal, or create temporary display
      console.warn("[VoiceFloat] Could not find voice-transcript element!")
      // Don't throw error - just log it
    }
    // Also update debug status
    this.updateDebugStatus(text)
    this.currentTranscript = text
  }

  private updateConnectionStatus(status: string, message: string): void {
    const el = document.getElementById("voice-connection-status")
    if (el) {
      el.textContent = message
      el.className = `connection-status ${status}`
    }
  }

  private updateDebugStatus(text: string): void {
    const el = document.getElementById("voice-debug-status")
    if (el) {
      el.textContent = text
    }
    console.log("[VoiceFloat] DEBUG:", text)
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
    console.log("[VoiceFloat] ensureModalStructure called")

    const existingModal = document.getElementById("voice-modal")
    if (existingModal) {
      console.log("[VoiceFloat] Modal already exists in DOM")
      this.modalElement = existingModal as HTMLElement
      return
    }

    console.log("[VoiceFloat] Creating new modal element")

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
        
        <div id="voice-connection-status" class="connection-status idle text-sm text-gray-500 mb-2">
          Connecting...
        </div>
        <div id="voice-debug-status" class="text-xs text-blue-600 mb-4 p-2 bg-blue-50 rounded text-center">
          Loading...
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
          <!-- Stop Button -->
          <button id="voice-stop-btn"
            class="mt-3 px-4 py-2 bg-red-500 hover:bg-red-600 text-white rounded-lg font-medium transition-colors flex items-center space-x-2 w-full justify-center">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
              <path d="M6 6h12v12H6z"/>
            </svg>
            <span>Done Talking</span>
          </button>
        </div>
      </div>
    `

    console.log("[VoiceFloat] Appending modal to body")
    document.body.appendChild(modal)
    console.log("[VoiceFloat] Modal appended, now adding event listeners")

    const closeBtn = document.getElementById("voice-close-btn")
    console.log("[VoiceFloat] closeBtn found:", !!closeBtn)
    closeBtn?.addEventListener("click", () => this.closeModal())

    // Stop button handler - closes the modal and stops all processing
    const stopBtn = document.getElementById("voice-stop-btn")
    console.log("[VoiceFloat] stopBtn found:", !!stopBtn)
    stopBtn?.addEventListener("click", () => {
      console.log("[VoiceFloat] Stop button clicked")
      window.speechSynthesis?.cancel()
      this.closeModal()
    })

    // Wake word toggle handler
    const wakeToggle = document.getElementById("wake-word-toggle")
    console.log("[VoiceFloat] wakeToggle found:", !!wakeToggle)
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
    console.log("[VoiceFloat] Modal setup complete, modalElement assigned")
  }
}
