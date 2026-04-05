/**
 * SimpleVoiceController - Simple click-to-talk voice for Pilot
 * No wake word needed - just click the button and talk
 */
/* eslint-disable max-len */

import { Controller, Context } from "@hotwired/stimulus"

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
  private isListening = false
  private isProcessing = false
  private continuousMode = false
  private silenceTimer: ReturnType<typeof setTimeout> | null = null
  private accumulatedTranscript: string = ''
  private silenceTimeoutMs: number = 5000  // 5 seconds
  private micIconPath = "M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"
  private onAiResponseHandler: () => void
  private enableContinuousHandler: () => void

  constructor(context: Context) {
    super(context)
    this.onAiResponseHandler = this.onAiResponseComplete.bind(this)
    this.enableContinuousHandler = this.enableContinuousMode.bind(this)
  }

  connect(): void {
    console.log("Voice flow active")
    console.log("[SimpleVoice] Controller connected")
    this.findElements()
    this.updateButtonReady()
    
    // Listen for AI response completion to trigger continuous mode
    window.addEventListener('ai:response-complete', this.onAiResponseHandler)
    window.addEventListener('voice:enable-continuous', this.enableContinuousHandler)
  }

  disconnect(): void {
    window.removeEventListener('ai:response-complete', this.onAiResponseHandler)
    window.removeEventListener('voice:enable-continuous', this.enableContinuousHandler)
  }

  private findElements(): void {
    this.button = document.getElementById('voice-float-btn')
    this.statusEl = document.getElementById('voice-status')
    this.responseEl = document.getElementById('voice-response')
  }

  toggle(event?: Event): void {
    console.log("[SimpleVoice] Button clicked")
    event?.preventDefault()
    
    if (this.isListening) {
      this.stopListening()
      return
    }
    
    if (this.isProcessing) {
      console.log("[SimpleVoice] Already processing, ignoring click")
      return
    }
    
    this.startListening()
  }

  private initializeSpeechRecognition(): boolean {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SpeechRecognition) {
      console.error("[SimpleVoice] Not supported")
      this.updateStatus("Voice not supported in this browser")
      return false
    }

    this.recognition = new SpeechRecognition()
    this.recognition.continuous = true
    this.recognition.interimResults = true
    this.recognition.lang = 'en-US'
    this.recognition.maxAlternatives = 1

    this.recognition.onstart = () => {
      console.log("[SimpleVoice] Started")
      this.isListening = true
      this.accumulatedTranscript = ''  // Clear any previous transcript
      this.updateButtonListening()
      this.updateStatus("Listening...")
      this.startSilenceTimer()  // Start silence detection
    }

    this.recognition.onresult = (event: SpeechRecognitionEvent) => {
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const result = event.results[i]
        const segment = result[0].transcript.trim()
        
        if (result.isFinal) {
          console.log("[SimpleVoice] Final segment:", segment)
          this.accumulatedTranscript += (this.accumulatedTranscript ? ' ' : '') + segment
          // Reset silence timer when we get final result
          this.resetSilenceTimer()
        } else {
          // Interim result - update status but keep accumulating
          if (segment) {
            this.updateStatus(`Hearing: "${this.accumulatedTranscript + (this.accumulatedTranscript ? ' ' : '') + segment}"`)
          }
          // Reset silence timer on interim results too
          this.resetSilenceTimer()
        }
      }
    }

    this.recognition.onend = () => {
      console.log("[SimpleVoice] Ended")
      this.isListening = false
      this.updateButtonReady()
      
      // If we have accumulated transcript when recognition ends, process it
      if (this.accumulatedTranscript.trim()) {
        console.log("[SimpleVoice] Processing accumulated transcript on end:", this.accumulatedTranscript)
        this.processVoiceInput(this.accumulatedTranscript)
        this.accumulatedTranscript = ''
      }
    }

    this.recognition.onerror = (event: SpeechRecognitionErrorEvent) => {
      console.error("[SimpleVoice] Error:", event.error)
      // Stop on errors
      this.isListening = false
      this.updateStatus(`Error: ${event.error}`)
      this.updateButtonReady()
      this.clearSilenceTimer()
      this.accumulatedTranscript = ''
    }

    return true
  }

  private startListening(): void {
    if (!this.initializeSpeechRecognition()) return
    
    try {
      this.recognition?.start()
    } catch (e) {
      console.error("[SimpleVoice] Start failed:", e)
    }
  }

  private stopListening(): void {
    if (this.recognition) {
      try {
        this.recognition.stop()
      } catch (e) {
        // Ignore errors when stopping - may already be stopped
        console.log("[SimpleVoice] Stop recognition:", e)
      }
    }
    this.isListening = false
    this.clearSilenceTimer()
    this.updateButtonReady()
    this.updateStatus("Ready")
  }

  private processVoiceInput(text: string): void {
    if (!text.trim()) return
    
    console.log("[SimpleVoice] Transcript received:", text)
    
    // Put transcript in the text input box
    const input = document.getElementById('message-input') as HTMLTextAreaElement | null
    if (input) {
      input.value = text.trim()
      input.focus()
    }
    
    // Show visual feedback that voice captured
    this.showVoiceCapturedFeedback(text)
    
    // Mark this as voice input
    if (this.button) {
      this.button.classList.add('voice-input-recent')
      setTimeout(() => {
        this.button?.classList.remove('voice-input-recent')
      }, 5000)
    }
    
    // AUTO-SEND for the floating red button - no manual send needed
    this.updateStatus("Sending...")
    this.updateButtonProcessing()
    this.isProcessing = true
    
    // Send to AI automatically
    this.handleVoiceSubmit(text.trim())
  }
  
  private async handleVoiceSubmit(text: string): Promise<void> {
    try {
      const conversationId = await this.getOrCreateConversation()
      if (!conversationId) {
        console.error("[SimpleVoice] No conversation ID")
        this.updateStatus("Error: No conversation")
        this.isProcessing = false
        this.updateButtonReady()
        return
      }
      
      // Send message and get response
      const response = await this.sendToAI(text, conversationId)
      
      // Display response
      this.displayResponse(response)
      
    } catch (e) {
      console.error("[SimpleVoice] Error:", e)
      this.updateStatus(`Error: ${(e as Error).message}`)
    } finally {
      this.isProcessing = false
      this.updateButtonReady()
    }
  }

  // Called by ai_chat_controller when AI finishes responding
  // This enables continuous voice mode after first voice interaction
  enableContinuousMode(): void {
    this.continuousMode = true
    this.updateButtonContinuous()
    console.log("[SimpleVoice] Continuous mode enabled - will auto-listen after AI responds")
    this.updateStatus("Continuous mode ON - AI will listen after responding")
  }

  disableContinuousMode(): void {
    this.continuousMode = false
    this.updateButtonReady()
    console.log("[SimpleVoice] Continuous mode disabled")
    this.updateStatus("Continuous mode OFF")
  }

  // Called after AI responds - starts listening if continuous mode is on
  onAiResponseComplete(): void {
    console.log("[SimpleVoice] onAiResponseComplete called, continuousMode:", this.continuousMode, "isListening:", this.isListening)
    if (this.continuousMode && !this.isListening && !this.isProcessing) {
      console.log("[SimpleVoice] AI responded, auto-starting listening...")
      this.updateStatus("Listening after AI response...")
      // Small delay then start listening
      setTimeout(() => {
        this.startListening()
      }, 500)
    } else {
      console.log("[SimpleVoice] Not auto-starting, continuousMode:", this.continuousMode, "isListening:", this.isListening, "isProcessing:", this.isProcessing)
    }
  }

  private updateButtonContinuous(): void {
    if (!this.button) return
    // Show pulsing animation to indicate continuous mode
    this.button.classList.add('animate-pulse')
    this.button.classList.remove('from-red-500', 'to-red-600')
    this.button.classList.add('from-purple-500', 'to-pink-500')
    const span = this.button.querySelector('span')
    if (span) span.textContent = "🎤 Listening..."
  }

  private showVoiceCapturedFeedback(_text: string): void {
    // Flash the input to show capture worked
    const input = document.getElementById('message-input')
    if (input) {
      input.classList.add('ring-2', 'ring-purple-500')
      setTimeout(() => {
        input.classList.remove('ring-2', 'ring-purple-500')
      }, 1000)
    }
  }

  private async getOrCreateConversation(): Promise<string | null> {
    // First try to get existing conversation from page
    let conversationId = ''
    
    // Check data attribute on page
    const convEl = document.querySelector('[data-conversation-id]')
    if (convEl) {
      conversationId = convEl.getAttribute('data-conversation-id') || ''
    }
    
    // Check URL path
    const pathMatch = window.location.pathname.match(/ai_chat\/(\d+)/)
    if (pathMatch) {
      conversationId = pathMatch[1]
    }
    
    // If we have a conversation ID, return it
    if (conversationId) {
      console.log("[SimpleVoice] Using existing conversation:", conversationId)
      return conversationId
    }
    
    // Otherwise create a new conversation
    console.log("[SimpleVoice] Creating new conversation...")
    try {
      const response = await fetch('/api/v1/ai_chat/create_conversation', {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json', 
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
        },
        credentials: 'include'
      })
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }
      
      const data = await response.json()
      console.log("[SimpleVoice] Created conversation:", data.conversation?.id)
      return data.conversation?.id || null
    } catch (e) {
      console.error("[SimpleVoice] Failed to create conversation:", e)
      return null
    }
  }

  private async sendToAI(text: string, conversationId: string): Promise<string> {
    console.log("[SimpleVoice] Sending to /api/v1/ai_chat/stream_message, conversation:", conversationId)
    
    const response = await fetch('/api/v1/ai_chat/stream_message', {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json', 
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
      },
      body: JSON.stringify({ 
        message: text,
        conversation_id: conversationId
      }),
      credentials: 'include'
    })

    if (!response.ok) {
      const err = await response.json().catch(() => ({ error: `HTTP ${response.status}` }))
      throw new Error(err.error || `HTTP ${response.status}`)
    }
    const data = await response.json()
    console.log("[SimpleVoice] Chat response received:", data)
    // Return the message content from the response
    return data.ai_message?.content || data.message || data.response || ''
  }

  private displayResponse(text: string): void {
    const responseTextEl = document.getElementById('voice-response-text')
    if (responseTextEl) {
      responseTextEl.textContent = text
      responseTextEl.classList.remove('hidden')
    }
    this.updateStatus("Done - listening...")
    
    // Also add to main chat container
    this.addMessageToChat('assistant', text)
    
    // Speak the response
    this.speakText(text)
    
    // Enable continuous mode and auto-listen for next input
    this.enableContinuousMode()
  }

  private addMessageToChat(role: string, content: string): void {
    const chatContainer = document.getElementById("chat-messages")
    if (!chatContainer) return

    // Remove empty state
    const empty = chatContainer.querySelector('.flex.flex-col.items-center.justify-center')
    if (empty) empty.remove()

    const isUser = role === 'user'
    const time = new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})
    
    const html = `<div class="message ${role} mb-4 flex ${isUser?'justify-end':'justify-start'}">
      <div class="flex ${isUser?'flex-row-reverse':'flex-row'} items-start gap-3 max-w-3xl">
        <div class="w-10 h-10 rounded-xl flex items-center justify-center ${isUser?'bg-gradient-to-br from-primary to-secondary':'bg-gradient-to-br from-green-500 to-emerald-500'}">
          ${isUser?'👤':'🤖'}
        </div>
        <div class="${isUser?'text-right':'text-left'}">
          <div class="inline-block p-4 rounded-2xl ${isUser?'bg-gradient-to-br from-primary to-secondary text-white':'bg-white border border-gray-200 text-gray-900'}">
            <p class="text-sm">${content}</p>
          </div>
          <p class="text-xs text-gray-500 mt-1">${time}</p>
        </div>
      </div>
    </div>`

    chatContainer.insertAdjacentHTML('afterbegin', html)
    chatContainer.scrollTop = 0
  }

  private speakText(text: string): void {
    if (!('speechSynthesis' in window)) return
    window.speechSynthesis.cancel()
    const utterance = new SpeechSynthesisUtterance(text)
    utterance.lang = 'en-US'
    
    // Get the selected voice from localStorage
    const selectedVoice = localStorage.getItem('otto_voice') || 'alloy'
    const voices = window.speechSynthesis.getVoices()
    
    // Try to find a matching voice
    const voice = voices.find(v => v.name.toLowerCase().includes(selectedVoice)) ||
                  voices.find(v => v.name.toLowerCase().includes('english')) ||
                  voices[0]
    
    if (voice) {
      utterance.voice = voice
    }
    
    window.speechSynthesis.speak(utterance)
  }

  private updateStatus(msg: string): void {
    console.log("[SimpleVoice]", msg)
    if (this.statusEl) {
      this.statusEl.textContent = msg
      this.statusEl.classList.remove('opacity-0')
      // Auto-hide after 3 seconds unless listening
      if (!this.isListening) {
        setTimeout(() => {
          this.statusEl?.classList.add('opacity-0')
        }, 3000)
      }
    }
  }

  private updateButtonReady(): void {
    if (this.button) {
      this.button.innerHTML = `
        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path>
        </svg>
        <span class="text-white font-medium text-sm pr-1">🎤 Talk to Pilot</span>
      `
      this.button.classList.remove('listening', 'processing')
    }
  }

  private updateButtonListening(): void {
    if (this.button) {
      this.button.classList.add('listening')
      this.button.innerHTML = `
        <svg class="w-6 h-6 text-white animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path>
        </svg>
        <span class="text-white font-medium text-sm pr-1">Listening...</span>
      `
    }
  }

  private updateButtonProcessing(): void {
    if (this.button) {
      this.button.classList.add('processing')
      this.button.innerHTML = `
        <svg class="w-6 h-6 text-white animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
        </svg>
        <span class="text-white font-medium text-sm pr-1">Thinking...</span>
      `
    }
  }

  // Start the silence detection timer
  private startSilenceTimer(): void {
    this.clearSilenceTimer()
    this.silenceTimer = setTimeout(() => {
      console.log("[SimpleVoice] 5 seconds of silence detected, processing transcript")
      if (this.accumulatedTranscript.trim()) {
        this.processVoiceInput(this.accumulatedTranscript)
        this.accumulatedTranscript = ''
      }
      this.stopListening()
    }, this.silenceTimeoutMs)
  }

  // Reset the silence timer (called when user speaks)
  private resetSilenceTimer(): void {
    if (this.silenceTimer) {
      clearTimeout(this.silenceTimer)
      this.silenceTimer = null
    }
    this.startSilenceTimer()
  }

  // Clear the silence timer
  private clearSilenceTimer(): void {
    if (this.silenceTimer) {
      clearTimeout(this.silenceTimer)
      this.silenceTimer = null
    }
  }
}
