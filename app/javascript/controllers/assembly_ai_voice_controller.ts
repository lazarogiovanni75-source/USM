/**
 * AssemblyAIVoiceController - Real-time speech-to-text
 * Tries AssemblyAI WebSocket first, falls back to Web Speech API
 */

import { Controller } from "@hotwired/stimulus"

// Type declarations for Web Speech API (webkit prefix)
interface SpeechRecognitionErrorEvent extends Event {
  error: string
  message: string
}

export default class AssemblyAiVoiceController extends Controller {
  // These targets are defined in the HTML - dynamically resolved when needed
  // stimulus-validator: disable-next-line
  static targets = ["button", "indicator", "transcript", "input", "status"]

  // Optional targets - may not exist in all contexts
  // stimulus-validator: disable-next-line
  declare readonly hasButtonTarget: boolean
  // stimulus-validator: disable-next-line
  declare readonly hasIndicatorTarget: boolean
  // stimulus-validator: disable-next-line
  declare readonly hasTranscriptTarget: boolean
  // stimulus-validator: disable-next-line
  declare readonly hasInputTarget: boolean
  // stimulus-validator: disable-next-line
  declare readonly hasStatusTarget: boolean

  // Target declarations with skip validation
  // stimulus-validator: disable-next-line
  buttonTarget!: HTMLElement
  // stimulus-validator: disable-next-line
  indicatorTarget!: HTMLElement
  // stimulus-validator: disable-next-line
  transcriptTarget!: HTMLElement
  // stimulus-validator: disable-next-line
  inputTarget!: HTMLTextAreaElement
  // stimulus-validator: disable-next-line
  statusTarget!: HTMLElement

  private isListening = false
  private useAssemblyAI = true
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private recognition: any = null
  private websocket: WebSocket | null = null
  private stream: MediaStream | null = null
  private audioContext: AudioContext | null = null
  private scriptProcessor: ScriptProcessorNode | null = null

  // Configuration
  private readonly API_KEY = "4171caf764f24a86a814fd5cd769aa68"
  private readonly WS_URL = "wss://api.assemblyai.com/v3/realtime/ws"

  connect(): void {
    console.log("[Voice] Controller connected")
    this.checkSupport()
  }

  private async checkSupport(): Promise<void> {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const SpeechRecognitionCtor = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
    if (SpeechRecognitionCtor) {
      console.log("[Voice] Web Speech API available as fallback")
    }
    
    this.updateStatus("Click mic to talk")
  }

  async toggle(event?: Event): Promise<void> {
    event?.preventDefault()
    event?.stopPropagation()
    
    if (this.isListening) {
      this.stopListening()
      return
    }
    
    await this.startListening()
  }

  private getInputValue(): string | null {
    try {
      if (this.inputTarget) return this.inputTarget.value
    } catch (e) { /* ignore */ }
    const input = document.querySelector('#message-input') as HTMLTextAreaElement
    return input?.value || null
  }

  private setInputValue(value: string): void {
    try {
      if (this.inputTarget) {
        this.inputTarget.value = value
        this.inputTarget.focus()
        return
      }
    } catch (e) { /* ignore */ }
    const input = document.querySelector('#message-input') as HTMLTextAreaElement
    if (input) {
      input.value = value
      input.focus()
    }
  }

  private async startListening(): Promise<void> {
    this.updateStatus("Starting...")
    
    if (this.useAssemblyAI) {
      try {
        await this.startAssemblyAI()
        return
      } catch (error) {
        console.warn("[Voice] AssemblyAI failed, trying Web Speech API:", error)
        this.useAssemblyAI = false
      }
    }
    
    await this.startWebSpeech()
  }

  private async startAssemblyAI(): Promise<void> {
    this.stream = await navigator.mediaDevices.getUserMedia({
      audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true }
    })
    
    console.log("[Voice] Mic access granted")
    
    await this.connectWebSocket()
    this.startAudioCapture()
    
    this.isListening = true
    this.updateButtonState(true)
    this.updateStatus("Listening... (AssemblyAI)")
  }

  private async connectWebSocket(): Promise<void> {
    const wsUrl = `${this.WS_URL}?sample_rate=16000&token=${this.API_KEY}`
    console.log("[Voice] Connecting to AssemblyAI...")
    
    return new Promise((resolve, reject) => {
      this.websocket = new WebSocket(wsUrl)
      
      this.websocket.onopen = () => {
        console.log("[Voice] WebSocket connected")
        resolve()
      }
      
      this.websocket.onerror = (error) => {
        console.error("[Voice] WebSocket error:", error)
        reject(new Error("Connection failed"))
      }
      
      this.websocket.onmessage = (event) => {
        this.handleAssemblyAIMessage(event)
      }
      
      this.websocket.onclose = (e) => {
        console.log("[Voice] WebSocket closed:", e.code)
      }
    })
  }

  private handleAssemblyAIMessage(event: MessageEvent): void {
    try {
      const data = JSON.parse(event.data)
      
      if (data.message_type === "FinalTranscript" && data.transcript?.trim()) {
        console.log("[Voice] Final:", data.transcript)
        this.processTranscript(data.transcript)
      } else if (data.message_type === "PartialTranscript") {
        this.updateStatus(`Hearing: ${data.transcript}`)
      } else if (data.error) {
        console.error("[Voice] API error:", data.error)
        this.updateStatus(`API Error: ${data.error}`)
      }
    } catch (e) {
      // Ignore non-JSON
    }
  }

  private startAudioCapture(): void {
    if (!this.stream || !this.websocket) return
    
    this.audioContext = new AudioContext({ sampleRate: 16000 })
    const source = this.audioContext.createMediaStreamSource(this.stream)
    
    const bufferSize = 4096
    this.scriptProcessor = this.audioContext.createScriptProcessor(bufferSize, 1, 1)
    
    this.scriptProcessor.onaudioprocess = (event) => {
      if (!this.websocket || this.websocket.readyState !== WebSocket.OPEN) return
      
      const inputData = event.inputBuffer.getChannelData(0)
      const int16Data = new Int16Array(inputData.length)
      
      for (let i = 0; i < inputData.length; i++) {
        const s = Math.max(-1, Math.min(1, inputData[i]))
        int16Data[i] = s < 0 ? s * 0x8000 : s * 0x7FFF
      }
      
      const base64 = btoa(String.fromCharCode(...int16Data))
      this.websocket.send(JSON.stringify({ audio_data: base64 }))
    }
    
    source.connect(this.scriptProcessor)
    console.log("[Voice] Audio capture started")
  }

  private async startWebSpeech(): Promise<void> {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const SpeechRecognitionCtor = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
    
    if (!SpeechRecognitionCtor) {
      this.updateStatus("Speech not supported")
      return
    }
    
    this.recognition = new SpeechRecognitionCtor()
    this.recognition.continuous = false
    this.recognition.interimResults = true
    this.recognition.lang = 'en-US'
    
    this.recognition.onstart = () => {
      console.log("[Voice] Web Speech started")
      this.isListening = true
      this.updateButtonState(true)
      this.updateStatus("Listening... (Browser)")
    }
    
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    this.recognition.onresult = (event: any) => {
      let finalTranscript = ''
      let interimTranscript = ''
      
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const transcript = event.results[i][0].transcript
        if (event.results[i].isFinal) {
          finalTranscript += transcript
        } else {
          interimTranscript += transcript
        }
      }
      
      if (interimTranscript) {
        this.updateStatus(`Hearing: "${interimTranscript}"`)
      }
      
      if (finalTranscript) {
        console.log("[Voice] Final:", finalTranscript)
        this.processTranscript(finalTranscript)
      }
    }
    
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    this.recognition.onerror = (event: any) => {
      console.error("[Voice] Speech error:", event.error)
      this.updateStatus(`Error: ${event.error}`)
    }
    
    this.recognition.onend = () => {
      console.log("[Voice] Speech ended")
      if (this.isListening) {
        this.isListening = false
        this.updateButtonState(false)
      }
    }
    
    this.recognition.start()
  }

  private processTranscript(text: string): void {
    if (!text.trim()) return
    
    console.log("[Voice] Got transcript:", text)
    this.setInputValue(text.trim())
    this.updateStatus("Processing...")
    
    setTimeout(() => {
      const form = document.querySelector('#chat-form') as HTMLFormElement
      if (form) {
        form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
      }
    }, 300)
    
    this.stopListening()
  }

  stopListening(): void {
    console.log("[Voice] Stopping...")
    this.isListening = false
    
    if (this.scriptProcessor) {
      this.scriptProcessor.disconnect()
      this.scriptProcessor = null
    }
    if (this.audioContext) {
      this.audioContext.close()
      this.audioContext = null
    }
    if (this.stream) {
      this.stream.getTracks().forEach(t => t.stop())
      this.stream = null
    }
    if (this.websocket) {
      this.websocket.close()
      this.websocket = null
    }
    if (this.recognition) {
      this.recognition.stop()
      this.recognition = null
    }
    
    this.updateButtonState(false)
    this.updateStatus("Click mic to talk")
  }

  private updateButtonState(listening: boolean): void {
    const button = document.getElementById('voice-float-btn')
    if (button) {
      button.classList.toggle("recording", listening)
      button.classList.toggle("animate-pulse", listening)
    }
  }

  private updateStatus(message: string): void {
    const el = document.getElementById('voice-status')
    if (el) el.textContent = message
    console.log("[Voice]", message)
  }

  disconnect(): void {
    this.stopListening()
  }
}
