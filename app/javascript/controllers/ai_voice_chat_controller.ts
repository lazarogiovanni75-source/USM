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
      const buttonEl = document.querySelector('[data-ai-voice-chat-target="button"]') as HTMLButtonElement;
      buttonEl?.setAttribute('disabled', 'true')
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
      const transcriptEl = document.querySelector('[data-ai-voice-chat-target="transcript"]');
      if (transcriptEl) {
        transcriptEl.classList.remove('hidden')
        const statusEl = transcriptEl.querySelector('[data-ai-voice-chat-target="status"]')
        if (statusEl) {
          statusEl.textContent = finalTranscript || interimTranscript || 'Listening...'
        }
      }
      
      // Update input field
      const inputEl = document.querySelector('[data-ai-voice-chat-target="input"]') as HTMLTextAreaElement;
      if (inputEl) {
        inputEl.value = finalTranscript || interimTranscript
        inputEl.style.height = 'auto'
        const inputHeight = Math.min(inputEl.scrollHeight, 200)
        inputEl.style.height = `${inputHeight}px`
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
      const transcriptEl = document.querySelector('[data-ai-voice-chat-target="transcript"]');
      if (transcriptEl) {
        transcriptEl.classList.add('hidden')
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
    const buttonEl = document.querySelector('[data-ai-voice-chat-target="button"]') as HTMLButtonElement;
    const indicatorEl = document.querySelector('[data-ai-voice-chat-target="indicator"]');
    
    if (buttonEl) {
      if (listening) {
        buttonEl.classList.add('listening', 'animate-pulse')
        buttonEl.classList.remove('bg-white/80', 'border', 'border-border/50')
        buttonEl.classList.add('bg-red-500', 'text-white')
      } else {
        buttonEl.classList.remove('listening', 'animate-pulse', 'bg-red-500', 'text-white')
        buttonEl.classList.add('bg-white/80', 'border', 'border-border/50')
      }
    }
    
    if (indicatorEl) {
      if (listening) {
        indicatorEl.classList.remove('hidden')
      } else {
        indicatorEl.classList.add('hidden')
      }
    }
  }
  
  private updateStatus(text: string): void {
    const statusEl = document.querySelector('[data-ai-voice-chat-target="status"]');
    if (statusEl) {
      statusEl.textContent = text;
    }
  }
}
