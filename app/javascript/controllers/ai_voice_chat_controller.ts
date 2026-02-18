import { Controller } from "@hotwired/stimulus"

// AI Voice Chat Controller - Uses browser's webkitSpeechRecognition
export default class AiVoiceChatController extends Controller {
  static targets = ["input", "button", "indicator", "status", "transcript"]
  
  declare readonly inputTarget: HTMLTextAreaElement
  declare readonly buttonTarget: HTMLButtonElement
  declare readonly indicatorTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly transcriptTarget: HTMLElement
  
  private recognition: any = null
  private isRecording: boolean = false
  private isProcessing: boolean = false
  
  connect(): void {
    this.initializeSpeechRecognition()
    console.log("AI Voice Chat controller connected")
  }
  
  disconnect(): void {
    this.stopListening()
  }
  
  private initializeSpeechRecognition(): void {
    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
    
    if (!SpeechRecognition) {
      console.warn('Speech recognition not supported in this browser')
      this.updateStatus('Voice not supported')
      this.buttonTarget?.setAttribute('disabled', 'true')
      return
    }
    
    this.recognition = new SpeechRecognition()
    this.recognition.continuous = false
    this.recognition.interimResults = true
    this.recognition.lang = 'en-US'
    this.recognition.maxAlternatives = 1
    
    this.recognition.onstart = () => {
      this.isRecording = true
      this.updateUI(true)
      this.updateStatus('Listening... Speak now')
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
      
      // Update transcript display
      if (this.hasTarget('transcript')) {
        this.transcriptTarget.classList.remove('hidden')
        const statusEl = this.transcriptTarget.querySelector('[data-ai-voice-chat-target="status"]')
        if (statusEl) {
          statusEl.textContent = finalTranscript || interimTranscript || 'Listening...'
        }
      }
      
      // Update input field
      if (this.hasTarget('input')) {
        this.inputTarget.value = finalTranscript || interimTranscript
        this.inputTarget.style.height = 'auto'
        const inputHeight = Math.min(this.inputTarget.scrollHeight, 200)
        this.inputTarget.style.height = `${inputHeight}px`
      }
      
      // If we have final transcript, submit
      if (finalTranscript) {
        this.submitVoiceMessage()
      }
    }
    
    this.recognition.onerror = (event: any) => {
      console.error('Speech recognition error:', event.error)
      this.isRecording = false
      this.updateUI(false)
      
      if (event.error === 'not-allowed') {
        this.updateStatus('Microphone access denied')
      } else if (event.error !== 'aborted') {
        this.updateStatus(`Error: ${event.error}`)
      }
    }
    
    this.recognition.onend = () => {
      this.isRecording = false
      this.updateUI(false)
      
      if (!this.isProcessing) {
        this.updateStatus('Voice off')
      }
    }
  }
  
  toggle(): void {
    if (this.isProcessing) return
    
    if (this.isRecording) {
      this.stopListening()
    } else {
      this.startListening()
    }
  }
  
  private startListening(): void {
    if (!this.recognition) {
      this.initializeSpeechRecognition()
      if (!this.recognition) return
    }
    
    try {
      // Clear transcript display
      if (this.hasTarget('transcript')) {
        this.transcriptTarget.classList.add('hidden')
      }
      
      this.recognition.start()
    } catch (error: any) {
      console.error('Failed to start recognition:', error)
      if (error.message?.includes('already started')) {
        this.recognition.stop()
      }
    }
  }
  
  private stopListening(): void {
    if (this.recognition && this.isRecording) {
      try {
        this.recognition.stop()
      } catch (e) {
        // Ignore
      }
    }
    this.isRecording = false
    this.updateUI(false)
  }
  
  submitVoiceMessage(): void {
    this.isProcessing = true
    this.updateStatus('Processing...')
    
    const chatForm = document.getElementById('chat-form') as HTMLFormElement
    if (chatForm) {
      chatForm.requestSubmit()
    }
    
    // Reset after a delay
    setTimeout(() => {
      this.isProcessing = false
      if (!this.isRecording) {
        this.updateStatus('Voice off')
      }
    }, 2000)
  }
  
  private updateUI(listening: boolean): void {
    if (listening) {
      this.buttonTarget.classList.add('listening', 'animate-pulse')
      this.buttonTarget.classList.remove('bg-white/80', 'border', 'border-border/50')
      this.buttonTarget.classList.add('bg-red-500', 'text-white')
      this.indicatorTarget?.classList.remove('hidden')
    } else {
      this.buttonTarget.classList.remove('listening', 'animate-pulse', 'bg-red-500', 'text-white')
      this.buttonTarget.classList.add('bg-white/80', 'border', 'border-border/50')
      this.indicatorTarget?.classList.add('hidden')
    }
  }
  
  private updateStatus(text: string): void {
    if (this.hasTarget('status')) {
      this.statusTarget.textContent = text
    }
  }
  
  private hasTarget(name: string): boolean {
    return (this as any).hasTarget(name)
  }
}
