import { Controller } from "@hotwired/stimulus"

export default class VoiceCommandToggleController extends Controller<HTMLElement> {
  private recognition: any = null
  private isListening: boolean = false

  connect(): void {
    console.log('🎤 Voice: Controller connected')
  }

  disconnect(): void {
    this.stopListening()
  }

  toggle(): void {
    console.log('🎤 Voice: Toggle clicked, isListening:', this.isListening)
    
    if (this.isListening) {
      this.stopListening()
    } else {
      this.startListening()
    }
  }

  private startListening(): void {
    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
    if (!SpeechRecognition) {
      console.error('🎤 Voice: Not supported - browser does not have SpeechRecognition')
      return
    }

    // Create fresh instance each time - REQUIRED for restart to work
    this.recognition = new SpeechRecognition()
    this.recognition.continuous = false
    this.recognition.interimResults = true
    this.recognition.lang = 'en-US'

    this.isListening = true
    this.updateUI(true)

    this.recognition.onstart = () => {
      console.log('🎤 Voice: Started listening')
    }

    this.recognition.onresult = (event: any) => {
      let final = ''
      for (let i = event.resultIndex; i < event.results.length; i++) {
        if (event.results[i].isFinal) {
          final += event.results[i][0].transcript
        }
      }
      if (final) {
        console.log('🎤 Voice: Heard:', final)
        this.showTranscript(final)
        this.sendToAI(final)
      }
    }

    this.recognition.onerror = (event: any) => {
      console.log('🎤 Voice: Error:', event.error)
      this.isListening = false
      this.updateUI(false)
    }

    this.recognition.onend = () => {
      console.log('🎤 Voice: Ended, auto-restarting...')
      this.isListening = false
      this.updateUI(false)
      
      // Auto-restart for continuous conversation
      setTimeout(() => {
        if (!this.isListening) {
          console.log('🎤 Voice: Auto-restarting...')
          this.startListening()
        }
      }, 500)
    }

    try {
      this.recognition.start()
    } catch (e: any) {
      console.log('🎤 Voice: Start error:', e.message)
      this.isListening = false
      this.updateUI(false)
    }
  }

  private stopListening(): void {
    this.isListening = false
    if (this.recognition) {
      try {
        this.recognition.stop()
      } catch (e) {
        // Ignore errors when stopping
      }
    }
    this.updateUI(false)
  }

  private showTranscript(text: string): void {
    const display = document.getElementById('voice-transcript-display')
    const el = document.getElementById('voice-transcript')
    if (display && el) {
      display.classList.remove('hidden')
      el.textContent = text
    }
  }

  private updateUI(listening: boolean): void {
    const btn = this.element as HTMLButtonElement
    const status = document.getElementById('voice-status')
    
    if (listening) {
      btn.classList.add('bg-red-500', 'animate-pulse')
      btn.classList.remove('bg-green-500')
      if (status) status.textContent = 'Listening...'
    } else {
      btn.classList.remove('bg-red-500', 'animate-pulse')
      btn.classList.add('bg-green-500')
      if (status) status.textContent = ''
    }
  }

  private async sendToAI(text: string): Promise<void> {
    this.updateStatus('Thinking...')
    
    try {
      const res = await fetch('/api/v1/voice/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text })
      })
      
      const data = await res.json()
      
      if (data.response) {
        this.showResponse(data.response)
      } else if (data.error) {
        this.updateStatus(`Error: ${data.error}`)
      }
    } catch (e) {
      console.error('🎤 Voice: API error:', e)
      this.updateStatus('Error')
    }
  }

  private showResponse(text: string): void {
    const display = document.getElementById('voice-response-display')
    const el = document.getElementById('voice-response-text')
    if (display && el) {
      display.classList.remove('hidden')
      el.textContent = text
    }
    this.updateStatus('')
  }

  private updateStatus(text: string): void {
    const el = document.getElementById('voice-status')
    if (el) el.textContent = text
  }

  closeModal(): void {
    const display = document.getElementById('voice-transcript-display')
    const responseDisplay = document.getElementById('voice-response-display')
    if (display) display.classList.add('hidden')
    if (responseDisplay) responseDisplay.classList.add('hidden')
    this.stopListening()
  }
}
