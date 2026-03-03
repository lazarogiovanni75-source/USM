/**
 * SimpleVoiceController - Simple click-to-talk voice for Otto
 * No wake word needed - just click the button and talk
 */
/* eslint-disable max-len */

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
  private isListening = false
  private isProcessing = false
  private micIconPath = "M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"

  connect(): void {
    console.log("Voice flow active")
    console.log("[SimpleVoice] Controller connected")
    this.findElements()
    this.updateButtonReady()
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
    
    this.startListening()
  }

  private initializeSpeechRecognition(): boolean {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SpeechRecognition) {
      console.error("[SimpleVoice] Not supported")
      this.updateStatus("Voice not supported")
      return false
    }

    this.recognition = new SpeechRecognition()
    this.recognition.continuous = false
    this.recognition.interimResults = true
    this.recognition.lang = 'en-US'
    this.recognition.maxAlternatives = 1

    this.recognition.onstart = () => {
      console.log("[SimpleVoice] Started")
      this.isListening = true
      this.updateButtonListening()
      this.updateStatus("Listening...")
    }

    this.recognition.onresult = (event: SpeechRecognitionEvent) => {
      let transcript = ''
      
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const result = event.results[i]
        transcript = result[0].transcript
        
        if (result.isFinal) {
          console.log("[SimpleVoice] Final:", transcript)
          this.processVoiceInput(transcript)
          return
        }
      }
      
      // Interim result
      if (transcript) {
        this.updateStatus(`Hearing: "${transcript}"`)
      }
    }

    this.recognition.onend = () => {
      console.log("[SimpleVoice] Ended")
      this.isListening = false
      this.updateButtonReady()
    }

    this.recognition.onerror = (event: SpeechRecognitionErrorEvent) => {
      console.error("[SimpleVoice] Error:", event.error)
      // Stop on errors
      this.isListening = false
      this.updateStatus(`Error: ${event.error}`)
      this.updateButtonReady()
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
    this.updateButtonReady()
    this.updateStatus("Ready")
  }

  private async processVoiceInput(text: string): Promise<void> {
    if (!text.trim()) return
    
    console.log("Transcript received")
    this.isProcessing = true
    this.updateButtonProcessing()
    this.updateStatus("Thinking...")

    // Add user's message to chat immediately
    this.addMessageToChat('user', text)

    try {
      const response = await this.sendToAI(text)
      this.displayResponse(response)
    } catch (e: any) {
      console.error("[SimpleVoice] Error:", e)
      this.updateStatus(`Error: ${e.message}`)
    } finally {
      this.isProcessing = false
      this.updateButtonReady()
    }
  }

  private async sendToAI(text: string): Promise<string> {
    console.log("Sending to /api/v1/ai_chat/stream_message (with tools)")
    
    // Get conversation ID - try multiple sources
    let conversationId = ''
    const urlParams = new URLSearchParams(window.location.search)
    const pathMatch = window.location.pathname.match(/ai_chat\/(\d+)/)
    
    // Check URL path first
    if (pathMatch) {
      conversationId = pathMatch[1]
    }
    // Check data attribute on page
    const convEl = document.querySelector('[data-conversation-id]')
    if (convEl) {
      conversationId = convEl.getAttribute('data-conversation-id') || ''
    }
    
    console.log("[SimpleVoice] Using conversation ID:", conversationId)
    
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
    this.updateStatus("Done")
    
    // Also add to main chat container
    this.addMessageToChat('assistant', text)
    
    this.speakText(text)
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
    if (this.statusEl) this.statusEl.textContent = msg
  }

  private updateButtonReady(): void {
    if (this.button) {
      this.button.innerHTML = `
        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path>
        </svg>
        <span class="text-white font-medium text-sm pr-1">🎤 Talk to Otto</span>
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
}
