declare global {
  interface Window {
    SpeechRecognition?: any
    webkitSpeechRecognition?: any
  }
}
import { Controller } from "@hotwired/stimulus"

// Voice Command Toggle Controller - Handles the voice command modal in AI Chat
export default class VoiceCommandToggleController extends Controller {
  private recognition: any = null
  private transcriptEl: HTMLElement | null = null
  private isRecording: boolean = false

  connect() {
    // this.element is the modal itself since data-controller is on the modal div
    this.transcriptEl = this.element.querySelector('#voice-transcript')
  }

  toggleVoice(event?: Event) {
    event?.preventDefault()
    this.openModal()
  }

  openModal() {
    this.element.classList.remove('hidden')
    // Trigger animation
    setTimeout(() => {
      this.element.querySelector('.relative')?.classList.remove('scale-95', 'opacity-0')
      this.element.querySelector('.relative')?.classList.add('scale-100', 'opacity-100')
    }, 10)
    // Start voice recognition
    this.startRecognition()
  }

  closeModal(event?: Event) {
    event?.preventDefault?.()
    this.element.querySelector('.relative')?.classList.remove('scale-100', 'opacity-100')
    this.element.querySelector('.relative')?.classList.add('scale-95', 'opacity-0')
    setTimeout(() => {
      this.element.classList.add('hidden')
    }, 200)
    if (this.recognition) {
      this.recognition.stop()
      this.recognition = null
    }
  }

  private startRecognition() {
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      this.updateTranscript('Voice recognition not supported in this browser')
      return
    }

    const SpeechRecognitionClass = window.SpeechRecognition || window.webkitSpeechRecognition
    this.recognition = new SpeechRecognitionClass()
    this.recognition.continuous = true
    this.recognition.interimResults = true

    this.recognition.onresult = (event: any) => {
      const transcript = Array.from(event.results)
        .map((result: any) => result[0])
        .map((result: any) => result.transcript)
        .join('')
      this.updateTranscript(transcript || 'Listening...')
    }

    this.recognition.onerror = (event: any) => {
      console.error('Speech recognition error:', event.error)
      const errorMessages: Record<string, string> = {
        'no-speech': 'No speech detected. Please try again and speak clearly.',
        'audio-capture': 'No microphone found. Please check your microphone.',
        'not-allowed': 'Microphone permission denied. Please allow microphone access.',
        'network': 'Network error. Please check your connection.',
        'aborted': 'Speech recognition aborted. Please try again.',
        'language-not-supported': 'English language not supported in this browser.',
        'service-not-allowed': 'Speech recognition service not allowed.'
      }
      const errorMessage = errorMessages[event.error] || `Error: ${event.error}`
      this.updateTranscript(errorMessage)
      this.isRecording = false
    }

    this.recognition.start()
  }

  private updateTranscript(text: string) {
    if (this.transcriptEl) {
      this.transcriptEl.textContent = text
    }
  }
}
