/**
 * SimpleVoiceController - Clean voice input for Otto-Pilot
 * Uses browser's built-in SpeechRecognition API (Web Speech API)
 * No audio recording/encoding needed - browser handles speech-to-text
 */

import { Controller } from "@hotwired/stimulus"

interface SpeechRecognitionEvent extends Event {
  results: SpeechRecognitionResultList
  resultIndex: number
}

interface SpeechRecognitionResultList {
  length: number
  item(index: number): SpeechRecognitionResult
  [index: number]: SpeechRecognitionResult
}

interface SpeechRecognitionResult {
  length: number
  item(index: number): SpeechRecognitionAlternative
  [index: number]: SpeechRecognitionAlternative
  isFinal: boolean
}

interface SpeechRecognitionAlternative {
  transcript: string
  confidence: number
}

interface SpeechRecognition extends EventTarget {
  continuous: boolean
  interimResults: boolean
  lang: string
  maxAlternatives: number
  onstart: (() => void) | null
  onend: (() => void) | null
  onerror: ((event: SpeechRecognitionErrorEvent) => void) | null
  onresult: ((event: SpeechRecognitionEvent) => void) | null
  onnomatch: ((event: SpeechRecognitionEvent) => void) | null
  start(): void
  stop(): void
  abort(): void
}

interface SpeechRecognitionErrorEvent extends Event {
  error: string
  message?: string
}

declare global {
  interface Window {
    SpeechRecognition: new () => SpeechRecognition
    webkitSpeechRecognition: new () => SpeechRecognition
  }
}

export default class SimpleVoiceController extends Controller {
  private button: HTMLElement | null = null
  private statusEl: HTMLElement | null = null
  private responseEl: HTMLElement | null = null
  private recognition: SpeechRecognition | null = null
  private recognitionStartTimeout: ReturnType<typeof setTimeout> | null = null
  private isListening = false
  private isProcessing = false
  private userId: number | null = null
  private conversationId: number | null = null
  private autoRestart = true
  private wakeWordEnabled = false
  private wakeWordDetected = false
  private wakePhrase = "hey Otto"
  private pendingCommand = ""
  private micIconPath = "M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"

  private loadConversationId(): void {
    // Get conversation ID from page's data attribute (set by ai-chat controller)
    const container = document.querySelector('[data-ai-chat-conversation-id-value]')
    if (container) {
      const convId = container.getAttribute('data-ai-chat-conversation-id-value')
      if (convId) {
        this.conversationId = parseInt(convId, 10)
        console.log("[SimpleVoice] Using conversation:", this.conversationId)
      }
    }
    if (!this.conversationId) {
      console.warn("[SimpleVoice] No conversation ID found on page")
    }
  }

  connect(): void {
    console.log("[SimpleVoice] Connected - looking for button and initializing")
    this.loadConversationId()
    this.loadWakeWordSettings()
    this.initializeSpeechRecognition()
    this.findElements()
    console.log("[SimpleVoice] Controller initialized, recognition available:", !!this.recognition)
    
    // If wake word was previously enabled, start listening
    if (this.wakeWordEnabled) {
      console.log("[SimpleVoice] Wake word was enabled, starting continuous listening")
      this.enableWakeWordMode()
    }
  }

  private loadWakeWordSettings(): void {
    // Load wake word preference
    const wakeEnabled = localStorage.getItem('wake_word_enabled')
    this.wakeWordEnabled = wakeEnabled === 'true'
    
    // Load custom wake phrase if any
    const savedPhrase = localStorage.getItem('wake_phrase')
    if (savedPhrase) {
      this.wakePhrase = savedPhrase.toLowerCase()
    }
    
    console.log(`[SimpleVoice] Wake word: enabled=${this.wakeWordEnabled}, phrase="${this.wakePhrase}"`)
  }

  private enableWakeWordMode(): void {
    if (!this.recognition) return
    
    this.wakeWordEnabled = true
    this.autoRestart = false  // Disable auto-restart in wake word mode
    localStorage.setItem('wake_word_enabled', 'true')
    
    // Update button to show wake word is active
    if (this.button) {
      this.button.classList.add('wake-word-active')
      this.button.innerHTML = `
        <svg class="w-6 h-6 text-white animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${this.micIconPath}"></path>
        </svg>
        <span class="text-white font-medium text-sm pr-1">Listening...</span>
      `
    }
    
    this.updateStatus("Say 'Hey Otto' to activate")
    this.startListening()
  }

  private disableWakeWordMode(): void {
    this.wakeWordEnabled = false
    this.autoRestart = false
    this.wakeWordDetected = false
    this.pendingCommand = ""
    localStorage.setItem('wake_word_enabled', 'false')
    
    // Stop recognition completely
    this.stopListening()
    
    // Reset button
    if (this.button) {
      this.button.classList.remove('wake-word-active')
      this.button.innerHTML = `
        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${this.micIconPath}"></path>
        </svg>
        <span class="text-white font-medium text-sm pr-1">Otto-Pilot</span>
      `
    }
    
    this.updateStatus("Wake word disabled")
  }

  disconnect(): void {
    this.stopListening()
  }

  private loadUserId(): void {
    const meta = document.querySelector('meta[name="user-id"]')
    if (meta) {
      const id = meta.getAttribute('content')
      this.userId = id && id !== 'anonymous' ? parseInt(id, 10) : null
    }
  }

  private findElements(): void {
    this.button = document.getElementById('voice-float-btn')
    this.statusEl = document.getElementById('voice-status')
    this.responseEl = document.getElementById('voice-response')
  }

  private initializeSpeechRecognition(): void {
    // First check if the browser supports the API at all
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SpeechRecognition) {
      console.warn("[SimpleVoice] Not supported - no SpeechRecognition API")
      this.updateStatus("Voice not supported on this browser")
      this.showVoiceNotSupported()
      return
    }

    console.log("[SimpleVoice] SpeechRecognition API available")
    
    try {
      this.recognition = new SpeechRecognition()
    } catch (e: any) {
      console.error("[SimpleVoice] Failed to create SpeechRecognition:", e)
      this.updateStatus(`Voice error: ${e.message}`)
      return
    }

    this.recognition.continuous = true // Enable continuous for wake word detection
    this.recognition.interimResults = true // Get interim results to detect wake word quickly
    this.recognition.lang = 'en-US'
    this.recognition.maxAlternatives = 1

    this.recognition.onstart = () => {
      console.log("[SimpleVoice] Recognition started!")
      this.isListening = true
      this.updateStatus("Listening... Speak now!")
      this.updateUIListening(true)
    }

    this.recognition.onresult = (event: SpeechRecognitionEvent) => {
      console.log("[SimpleVoice] Got result:", event.results)
      
      // Process all results (both interim and final)
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const result = event.results[i]
        const transcript = result[0].transcript.trim().toLowerCase()
        
        console.log("[SimpleVoice] Transcript:", transcript, "isFinal:", result.isFinal)
        
        // Wake word detection mode
        if (this.wakeWordEnabled && !this.wakeWordDetected) {
          if (transcript.includes(this.wakePhrase)) {
            console.log("[SimpleVoice] WAKE WORD DETECTED!")
            this.wakeWordDetected = true
            this.updateStatus("🎯 Listening for your command...")
            // Continue listening for the actual command
          }
        }
        
        // If wake word was detected, treat this as the command
        if (this.wakeWordEnabled && this.wakeWordDetected && result.isFinal && transcript) {
          // Remove the wake phrase from the command
          let command = result[0].transcript.trim()
          command = command.replace(new RegExp(this.wakePhrase, 'gi'), '').trim()
          
          if (command.length > 0) {
            console.log("[SimpleVoice] Command after wake word:", command)
            this.pendingCommand = command
            this.updateStatus(`Executing: "${command}"`)
            
            // Process the command
            this.processVoiceInput(command).then(() => {
              // Reset after processing
              this.wakeWordDetected = false
              this.pendingCommand = ""
              
              // Continue listening for more commands
              if (this.wakeWordEnabled) {
                this.updateStatus("Say 'Hey Otto' again for another command")
              }
            })
            return // Don't process further
          }
        }
        
        // Normal mode (no wake word) - process final results
        if (!this.wakeWordEnabled && result.isFinal) {
          const finalTranscript = result[0].transcript.trim()
          if (finalTranscript) {
            console.log("[SimpleVoice] Final transcript:", finalTranscript)
            const wasAutoRestart = this.autoRestart
            this.autoRestart = false
            this.processVoiceInput(finalTranscript).then(() => {
              if (wasAutoRestart) {
                this.autoRestart = true
              }
            })
          }
          return
        }
      }
    }

    this.recognition.onend = () => {
      console.log("[SimpleVoice] Recognition ended")
      this.isListening = false
      this.updateUIListening(false)
      // Don't auto-restart here - only restart after processing a response
      // This prevents the on/off loop when silence is detected
      // Also reset the recognition object to prevent "already started" errors
      this.recognition = null
      // Reinitialize for next use
      setTimeout(() => this.initializeSpeechRecognition(), 100)
    }

    this.recognition.onerror = (event: SpeechRecognitionErrorEvent) => {
      console.error("[SimpleVoice] Error:", event.error, event.message)
      this.updateStatus(`Error: ${event.error}`)
      // Reset recognition to prevent "already started" errors
      this.recognition = null
      // Reinitialize for next use
      setTimeout(() => this.initializeSpeechRecognition(), 100)
    }
  }

  toggle(event?: Event): void {
    console.log("[SimpleVoice] Toggle called, event:", event, "isListening:", this.isListening, "autoRestart:", this.autoRestart, "wakeWordEnabled:", this.wakeWordEnabled)
    event?.preventDefault()
    
    // If wake word is enabled, toggle it off
    if (this.wakeWordEnabled) {
      this.disableWakeWordMode()
      return
    }
    
    // Show menu to enable wake word or start manual voice
    if (!this.recognition) {
      this.updateStatus("Voice not supported")
      return
    }
    
    // Simple toggle: start/stop manual listening
    if (this.isListening || this.autoRestart) {
      console.log("[SimpleVoice] Stopping listening")
      this.autoRestart = false
      this.stopListening()
      this.updateStatus("Ready - tap to talk")
    } else {
      console.log("[SimpleVoice] Starting manual listening")
      this.autoRestart = true
      this.wakeWordEnabled = false
      this.updateStatus("Listening... Speak now!")
      this.startListening()
    }
  }

  // New method: Long press or double-tap to enable wake word mode
  enableWakeWord(event?: Event): void {
    event?.preventDefault()
    console.log("[SimpleVoice] Enabling wake word mode")
    this.enableWakeWordMode()
  }

  // Disable wake word
  disableWakeWord(event?: Event): void {
    event?.preventDefault()
    console.log("[SimpleVoice] Disabling wake word mode")
    this.disableWakeWordMode()
  }

  startListening(): void {
    // More robust guard - check if recognition exists and is in a valid state
    if (!this.recognition) {
      console.log("[SimpleVoice] Cannot start: no recognition object, reinitializing...")
      // Reinitialize recognition if it's null
      this.initializeSpeechRecognition()
      setTimeout(() => this.startListening(), 200)
      return
    }
    
    // Check if already listening or processing
    if (this.isListening) {
      console.log("[SimpleVoice] Cannot start: already listening, isListening=", this.isListening)
      return
    }
    
    // Guard against rapid restart calls on mobile
    if (this.recognitionStartTimeout) {
      clearTimeout(this.recognitionStartTimeout)
      this.recognitionStartTimeout = null
    }
    
    console.log("[SimpleVoice] Attempting to start recognition...")
    try {
      // Check if recognition is in a state where we can start it
      // Sometimes the browser holds onto the recognition object even after stopping
      try {
        // First try to stop any existing recognition
        this.recognition.stop()
      } catch (e) {
        // Ignore - recognition might not be running
      }
      
      // Small delay to ensure clean state
      setTimeout(() => {
        try {
          this.recognition?.start()
          console.log("[SimpleVoice] recognition.start() called successfully")
        } catch (startError: any) {
          if (startError.message?.includes('already started')) {
            console.log("[SimpleVoice] Recognition already running, waiting for it to stop...")
            // Wait a bit longer and try again
            this.recognitionStartTimeout = setTimeout(() => this.startListening(), 500)
          } else {
            console.error("[SimpleVoice] Failed to start recognition:", startError)
          }
        }
      }, 100)
    } catch (e: any) {
      console.error("[SimpleVoice] Failed to start recognition:", e)
    }
  }

  stopListening(): void {
    if (this.recognition && this.isListening) {
      try { this.recognition.stop() } catch(e) { /* ignore */ }
    }
    this.isListening = false
    this.updateUIListening(false)
  }

  private async processVoiceInput(text: string): Promise<void> {
    this.isProcessing = true
    this.updateStatus(`Processing: "${text}"`)
    this.updateUIProcessing(true)

    try {
      const response = await this.sendToOttoPilot(text)
      this.displayResponse(response)
      // Auto-restart ONLY in manual mode (not wake word mode)
      // and only if the user explicitly wants continuous listening
      if (this.autoRestart && !this.wakeWordEnabled) {
        setTimeout(() => this.startListening(), 1500)
      }
    } catch (e: any) {
      this.updateStatus(`Error: ${e.message}`)
    } finally {
      this.isProcessing = false
      this.updateUIProcessing(false)
    }
  }

  private async sendToOttoPilot(text: string): Promise<string> {
    console.log("[SimpleVoice] Sending:", text, "to conversation:", this.conversationId)

    if (!this.conversationId) {
      console.error("[SimpleVoice] No conversation ID found on page")
      throw new Error("No conversation. Please refresh the page and try again.")
    }

    const response = await fetch('/api/v1/ai_chat/stream_message', {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json', 
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
      },
      body: JSON.stringify({ conversation_id: this.conversationId, message: text }),
      credentials: 'include'
    })

    if (!response.ok) {
      const err = await response.json().catch(() => ({ error: `HTTP ${response.status}` }))
      throw new Error(err.error || `HTTP ${response.status}`)
    }
    const data = await response.json()
    return data.response || data.message || ''
  }

  private displayResponse(text: string): void {
    if (this.responseEl) {
      this.responseEl.textContent = text
      this.responseEl.classList.remove('hidden')
    }
    this.speakText(text)
    this.updateStatus("Ready")
  }

  private speakText(text: string): void {
    if (!('speechSynthesis' in window)) return
    window.speechSynthesis.cancel()
    const utterance = new SpeechSynthesisUtterance(text)
    utterance.lang = 'en-US'
    
    // Try to select a male voice
    const voices = window.speechSynthesis.getVoices()
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
    }
    
    window.speechSynthesis.speak(utterance)
  }

  private updateStatus(msg: string): void {
    console.log("[SimpleVoice]", msg)
    if (this.statusEl) this.statusEl.textContent = msg
  }

  private showVoiceNotSupported(): void {
    // Update the floating button to show voice is not supported
    if (this.button) {
      this.button.classList.add('opacity-50', 'cursor-not-allowed')
      this.button.setAttribute('title', 'Voice not supported on this browser')
    }
    this.updateStatus('Voice not supported on this browser. Please try Chrome on desktop or Android.')
  }

  private updateUIListening(listening: boolean): void {
    this.button?.classList.toggle('animate-pulse', listening)
    this.button?.classList.toggle('listening', listening)
  }

  private updateUIProcessing(processing: boolean): void {
    this.button?.classList.toggle('processing', processing)
  }
}
