import { Controller } from "@hotwired/stimulus"

// AI Voice Chat Controller - Integrated voice for conversational AI chat like ChatGPT
// Handles continuous voice listening, transcription, and AI response streaming
// stimulus-validator: disable-next-line
export default class AiVoiceChatController extends Controller {
  // stimulus-validator: disable-next-line
  static targets = ["input", "button", "indicator", "status", "transcript"]
  
  declare readonly inputTarget: HTMLTextAreaElement
  declare readonly buttonTarget: HTMLButtonElement
  declare readonly indicatorTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly transcriptTarget: HTMLElement
  
  private recognition: any = null
  private isListening: boolean = false
  private isProcessing: boolean = false
  private conversationId: string | null = null
  private silenceTimer: ReturnType<typeof setTimeout> | null = null
  private readonly SILENCE_DELAY_MS = 1500 // Send after 1.5s of silence
  
  connect(): void {
    this.initializeSpeechRecognition()
    this.loadConversationId()
    console.log("AI Voice Chat controller connected")
  }
  
  disconnect(): void {
    this.stopListening()
  }
  
  private loadConversationId(): void {
    // Read conversation ID from the controller element's dataset
    const element = this.element as HTMLElement
    this.conversationId = element.dataset.aiVoiceChatConversationId || null
  }
  
  private initializeSpeechRecognition(): void {
    // Check for webkitSpeechRecognition (Chrome) or SpeechRecognition (standard)
    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
    if (!SpeechRecognition) {
      console.warn('Speech recognition not supported in this browser')
      this.updateStatus('Voice not supported')
      return
    }
    
    this.recognition = new SpeechRecognition()
    this.recognition.continuous = true // Keep listening continuously
    this.recognition.interimResults = true // Get interim results while speaking
    this.recognition.lang = 'en-US'
    
    this.recognition.onstart = () => {
      this.isListening = true
      this.updateUI(true)
      this.updateStatus('Listening...')
    }
    
    this.recognition.onend = () => {
      this.isListening = false
      // Auto-restart if still should be listening
      if (this.buttonTarget?.classList.contains('listening')) {
        this.recognition?.start()
      } else {
        this.updateUI(false)
        this.updateStatus('Voice off')
      }
    }
    
    this.recognition.onresult = (event: any) => {
      let interimTranscript = ''
      let finalTranscript = ''
      
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const transcript = event.results[i][0].transcript
        if (event.results[i].isFinal) {
          finalTranscript += transcript
        } else {
          interimTranscript += transcript
        }
      }
      
      // Update live transcript display
      if (this.hasTarget('transcript')) {
        this.transcriptTarget.classList.remove('hidden')
        const statusEl = this.transcriptTarget.querySelector('[data-ai-voice-chat-target="status"]')
        if (statusEl) {
          const transcriptText = finalTranscript || interimTranscript || 'Listening...'
          statusEl.textContent = transcriptText
        }
      }
      
      // Update input field with transcript
      if (this.hasTarget('input') && (finalTranscript || interimTranscript)) {
        this.inputTarget.value = finalTranscript || interimTranscript
        this.inputTarget.style.height = 'auto'
        const inputHeight = Math.min(this.inputTarget.scrollHeight, 200)
        this.inputTarget.style.height = `${inputHeight}px`
      }
      
      // Reset silence timer on new speech
      this.resetSilenceTimer()
      
      // If we have final transcript, send to AI after silence
      if (finalTranscript) {
        this.scheduleSend(finalTranscript)
      }
    }
    
    this.recognition.onerror = (event: any) => {
      console.error('Speech recognition error:', event.error)
      if (event.error === 'not-allowed') {
        this.updateStatus('Microphone access denied')
        this.hideTranscript()
      } else if (event.error !== 'aborted') {
        this.updateStatus(`Error: ${event.error}`)
      }
    }
  }
  
  private resetSilenceTimer(): void {
    if (this.silenceTimer) {
      clearTimeout(this.silenceTimer)
    }
    this.silenceTimer = setTimeout(() => {
      // Check if there's content to send
      if (this.hasTarget('input') && this.inputTarget.value.trim().length > 0) {
        this.submitVoiceMessage()
      }
    }, this.SILENCE_DELAY_MS)
  }
  
  private scheduleSend(transcript: string): void {
    // Schedule sending after silence delay
    this.silenceTimer = setTimeout(() => {
      if (this.hasTarget('input')) {
        this.inputTarget.value = transcript
        this.submitVoiceMessage()
      }
    }, this.SILENCE_DELAY_MS)
  }
  
  toggle(): void {
    if (this.isListening) {
      this.stopListening()
    } else {
      this.startListening()
    }
  }
  
  private async startListening(): Promise<void> {
    if (!this.recognition) {
      this.initializeSpeechRecognition()
      if (!this.recognition) return
    }
    
    try {
      // Clear any pending send
      if (this.silenceTimer) {
        clearTimeout(this.silenceTimer)
      }
      
      // Clear transcript display
      if (this.hasTarget('transcript')) {
        this.transcriptTarget.classList.add('hidden')
      }
      
      await this.recognition.start()
    } catch (error) {
      console.error('Failed to start recognition:', error)
    }
  }
  
  private stopListening(): void {
    if (this.recognition && this.isListening) {
      this.recognition.stop()
    }
    if (this.silenceTimer) {
      clearTimeout(this.silenceTimer)
    }
    this.isListening = false
    this.updateUI(false)
    this.updateStatus('Voice off')
    this.hideTranscript()
  }
  
  private hideTranscript(): void {
    if (this.hasTarget('transcript')) {
      this.transcriptTarget.classList.add('hidden')
    }
  }
  
  submitVoiceMessage(): void {
    // Find the chat form and submit it
    const chatForm = document.getElementById('chat-form') as HTMLFormElement
    if (chatForm) {
      chatForm.requestSubmit()
    }
  }
  
  private updateUI(listening: boolean): void {
    if (listening) {
      this.buttonTarget.classList.add('listening', 'animate-pulse')
      this.buttonTarget.classList.remove('bg-white/80', 'border', 'border-border/50')
      this.buttonTarget.classList.add('bg-success', 'text-white')
      this.indicatorTarget?.classList.remove('hidden')
    } else {
      this.buttonTarget.classList.remove('listening', 'animate-pulse', 'bg-success', 'text-white')
      this.buttonTarget.classList.add('bg-white/80', 'border', 'border-border/50')
      this.buttonTarget.classList.remove('text-white')
      this.indicatorTarget?.classList.add('hidden')
    }
  }
  
  private updateStatus(text: string): void {
    if (this.hasTarget('status')) {
      this.statusTarget.textContent = text
    }
  }
  
  private hasTarget(name: string): boolean {
    return this.targets.has(name)
  }
}
