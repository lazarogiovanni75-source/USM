import { Controller } from "@hotwired/stimulus"

// VoiceLoopController - Full voice conversation with Whisper → Claude → OpenAI TTS
// Push-to-talk pattern: hold mic button to record, release to send

interface Message {
  id: string
  role: 'user' | 'assistant'
  content: string
  timestamp: Date
}

export default class VoiceLoopController extends Controller<HTMLElement> {
  static targets = ['textInput', 'status']

  declare readonly textInputTarget: HTMLInputElement
  declare readonly statusTarget: HTMLElement

  // State
  private messages: Message[] = []
  private mediaRecorder: MediaRecorder | null = null
  private audioChunks: Blob[] = []
  private isRecording = false
  private conversationId: string | null = null
  private currentAudio: HTMLAudioElement | null = null

  // DOM elements (set via connect)
  private messagesContainer: HTMLElement | null = null
  private voiceButton: HTMLButtonElement | null = null
  private sendButton: HTMLButtonElement | null = null
  private resetButton: HTMLButtonElement | null = null

  connect(): void {
    this.messagesContainer = document.getElementById('messages-container')
    this.voiceButton = document.getElementById('voice-button') as HTMLButtonElement
    this.sendButton = document.getElementById('send-button') as HTMLButtonElement
    this.resetButton = document.getElementById('reset-button') as HTMLButtonElement

    this.setupEventListeners()
    this.setStatus('Ready')
  }

  disconnect(): void {
    this.stopRecording()
    if (this.currentAudio) {
      this.currentAudio.pause()
      this.currentAudio = null
    }
  }

  private setupEventListeners(): void {
    // Voice button - push to talk
    if (this.voiceButton) {
      this.voiceButton.addEventListener('mousedown', (e) => this.startRecording(e))
      this.voiceButton.addEventListener('mouseup', (e) => this.stopRecordingAndSend(e))
      this.voiceButton.addEventListener('mouseleave', () => this.cancelRecording())
      this.voiceButton.addEventListener('touchstart', (e) => this.startRecording(e))
      this.voiceButton.addEventListener('touchend', (e) => this.stopRecordingAndSend(e))
    }

    // Send button
    if (this.sendButton) {
      this.sendButton.addEventListener('click', () => this.sendTextMessage())
    }

    // Reset button
    if (this.resetButton) {
      this.resetButton.addEventListener('click', () => this.resetConversation())
    }

    // Text input enter key
    if (this.textInputTarget) {
      this.textInputTarget.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault()
          this.sendTextMessage()
        }
      })
    }
  }

  // ==================== Recording ====================

  async startRecording(event: Event): Promise<void> {
    event.preventDefault()

    if (this.isRecording) return

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.mediaRecorder = new MediaRecorder(stream, {
        mimeType: this.getSupportedMimeType()
      })
      this.audioChunks = []

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) {
          this.audioChunks.push(e.data)
        }
      }

      this.mediaRecorder.onstop = () => this.processRecording()

      this.mediaRecorder.start(100) // Collect data every 100ms
      this.isRecording = true
      this.updateRecordingUI(true)
      this.setStatus('Listening...')

    } catch (error) {
      console.error('[VoiceLoop] Failed to start recording:', error)
      this.setStatus('Microphone access denied')
    }
  }

  stopRecordingAndSend(event: Event): void {
    event.preventDefault()
    if (!this.isRecording || !this.mediaRecorder) return

    this.mediaRecorder.stop()
    this.mediaRecorder.stream.getTracks().forEach(track => track.stop())
    this.isRecording = false
    this.updateRecordingUI(false)
  }

  cancelRecording(): void {
    if (!this.isRecording) return

    this.mediaRecorder?.stop()
    this.mediaRecorder?.stream.getTracks().forEach(track => track.stop())
    this.isRecording = false
    this.audioChunks = []
    this.updateRecordingUI(false)
    this.setStatus('Ready')
  }

  private stopRecording(): void {
    if (!this.isRecording) return

    this.mediaRecorder?.stop()
    this.mediaRecorder?.stream.getTracks().forEach(track => track.stop())
    this.isRecording = false
    this.updateRecordingUI(false)
  }

  private getSupportedMimeType(): string {
    const types = ['audio/webm', 'audio/mp4', 'audio/ogg']
    for (const type of types) {
      if (MediaRecorder.isTypeSupported(type)) {
        return type
      }
    }
    return 'audio/webm'
  }

  private updateRecordingUI(isRecording: boolean): void {
    const micIcon = document.getElementById('mic-icon')
    const stopIcon = document.getElementById('stop-icon')
    const recordingRing = document.getElementById('recording-ring')

    if (isRecording) {
      micIcon?.classList.add('hidden')
      stopIcon?.classList.remove('hidden')
      recordingRing?.classList.remove('opacity-0')
      recordingRing?.classList.add('opacity-100', 'animate-pulse')
      this.voiceButton?.classList.add('bg-red-500')
      this.voiceButton?.classList.remove('bg-primary')
    } else {
      micIcon?.classList.remove('hidden')
      stopIcon?.classList.add('hidden')
      recordingRing?.classList.add('opacity-0')
      recordingRing?.classList.remove('opacity-100', 'animate-pulse')
      this.voiceButton?.classList.remove('bg-red-500')
      this.voiceButton?.classList.add('bg-primary')
    }
  }

  // ==================== Processing ====================

  private async processRecording(): Promise<void> {
    if (this.audioChunks.length === 0) {
      this.setStatus('No audio recorded')
      return
    }

    const audioBlob = new Blob(this.audioChunks, { type: this.getSupportedMimeType() })
    await this.runConversationLoop(audioBlob)
  }

  async sendTextMessage(): Promise<void> {
    const text = this.textInputTarget.value.trim()
    if (!text) return

    this.textInputTarget.value = ''
    await this.sendToClaude(text)
  }

  private async runConversationLoop(audioBlob: Blob): Promise<void> {
    try {
      // Step 1: Transcribe with Whisper
      this.setStatus('Transcribing...')
      this.setLoadingState(true)

      const transcribedText = await this.transcribeAudio(audioBlob)

      if (!transcribedText || transcribedText.trim().length < 2) {
        this.setStatus('Could not understand audio. Try again.')
        this.setLoadingState(false)
        return
      }

      // Display user message
      this.addMessageToUI('user', transcribedText)

      // Step 2 & 3: Send to Claude and speak
      await this.sendToClaude(transcribedText)

    } catch (error) {
      console.error('[VoiceLoop] Error:', error)
      this.setStatus(`Error: ${error instanceof Error ? error.message : 'Unknown error'}`)
      this.setLoadingState(false)
    }
  }

  private async transcribeAudio(audioBlob: Blob): Promise<string> {
    const formData = new FormData()
    formData.append('audio', audioBlob, `recording.${this.getExtension()}`)

    const response = await fetch('/api/v1/voice_loop/transcribe', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: formData
    })

    const data = await response.json()

    if (!response.ok) {
      throw new Error(data.error || 'Transcription failed')
    }

    return data.text || ''
  }

  private async sendToClaude(text: string): Promise<void> {
    try {
      this.setStatus('Thinking...')

      const response = await fetch('/api/v1/voice_loop/claude', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          message: text,
          conversation_id: this.conversationId
        })
      })

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.error || 'Failed to get response')
      }

      this.conversationId = data.conversation_id

      // Display assistant message
      this.addMessageToUI('assistant', data.response)

      // Step 3: Convert to speech
      await this.speakText(data.response)

    } catch (error) {
      console.error('[VoiceLoop] Claude error:', error)
      this.setStatus(`Error: ${error instanceof Error ? error.message : 'Unknown error'}`)
      this.setLoadingState(false)
    }
  }

  private async speakText(text: string): Promise<void> {
    try {
      this.setStatus('Speaking...')

      const response = await fetch('/api/v1/voice_loop/speak', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({ text })
      })

      if (!response.ok) {
        throw new Error('TTS failed')
      }

      const audioBlob = await response.blob()
      const audioUrl = URL.createObjectURL(audioBlob)

      // Play audio
      this.currentAudio = new Audio(audioUrl)

      await new Promise<void>((resolve, reject) => {
        if (this.currentAudio) {
          this.currentAudio.onended = () => {
            URL.revokeObjectURL(audioUrl)
            resolve()
          }
          this.currentAudio.onerror = (e) => {
            URL.revokeObjectURL(audioUrl)
            reject(new Error('Audio playback failed'))
          }
          this.currentAudio.play()
        } else {
          resolve()
        }
      })

      this.setStatus('Ready')
      this.setLoadingState(false)

    } catch (error) {
      console.error('[VoiceLoop] TTS error:', error)
      this.setStatus('Ready')
      this.setLoadingState(false)
    }
  }

  // ==================== Conversation Management ====================

  private async resetConversation(): Promise<void> {
    try {
      await fetch('/api/v1/voice_loop/reset', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.getCSRFToken()
        }
      })

      this.messages = []
      this.conversationId = null
      this.messagesContainer = document.getElementById('messages-container')
      if (this.messagesContainer) {
        this.messagesContainer.innerHTML = ''
      }

      this.setStatus('Conversation reset')
      this.addWelcomeMessage()

    } catch (error) {
      console.error('[VoiceLoop] Reset error:', error)
    }
  }

  // ==================== UI Updates ====================

  private addMessageToUI(role: 'user' | 'assistant', content: string): void {
    const container = document.getElementById('messages-container')
    if (!container) return

    const messageId = `msg-${Date.now()}`
    const isUser = role === 'user'

    const messageEl = document.createElement('div')
    messageEl.id = messageId
    messageEl.className = `flex gap-3 ${isUser ? 'flex-row-reverse' : ''}`
    const userIcon = '<svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">'
      + '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" '
      + 'd="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>'
      + '</svg>'
    const assistantIcon = '<svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">'
      + '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" '
      + 'd="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>'
      + '</svg>'
    const icon = isUser ? userIcon : assistantIcon
    const bubbleClass = isUser ? 'rounded-tr-sm bg-primary/10' : 'rounded-tl-sm'

    messageEl.innerHTML = `
      <div class="w-8 h-8 rounded-full flex-shrink-0 flex items-center justify-center ${
  isUser ? 'bg-primary' : 'bg-secondary'
}">${icon}</div>
      <div class="bg-surface-elevated rounded-2xl px-4 py-3 max-w-md ${bubbleClass}">
        <p class="text-sm text-primary leading-relaxed whitespace-pre-wrap">
          ${this.escapeHtml(content)}
        </p>
      </div>
    `

    container.appendChild(messageEl)
    container.scrollTop = container.scrollHeight

    this.messages.push({
      id: messageId,
      role,
      content,
      timestamp: new Date()
    })
  }

  private addWelcomeMessage(): void {
    const container = document.getElementById('messages-container')
    if (!container) return

    const welcomeEl = document.createElement('div')
    welcomeEl.className = 'flex gap-3'
    const welcomeMsg = "Hi! I'm your voice assistant powered by Claude. "
      + "Hold the mic button to talk, or type your message below."
    const assistantIcon = '<svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">'
      + '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" '
      + 'd="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>'
      + '</svg>'

    welcomeEl.innerHTML = `
      <div class="w-8 h-8 rounded-full bg-secondary flex-shrink-0 flex items-center justify-center">
        ${assistantIcon}
      </div>
      <div class="bg-surface-elevated rounded-2xl rounded-tl-sm px-4 py-3 max-w-md">
        <p class="text-sm text-primary leading-relaxed">${welcomeMsg}</p>
      </div>
    `

    container.appendChild(welcomeEl)
  }

  private setStatus(status: string): void {
    const statusEl = document.getElementById('status-text')
    if (statusEl) {
      statusEl.textContent = status
    }
  }

  private setLoadingState(loading: boolean): void {
    const loadingEl = document.getElementById('loading-indicator')
    if (loadingEl) {
      if (loading) {
        loadingEl.classList.remove('hidden')
      } else {
        loadingEl.classList.add('hidden')
      }
    }

    if (this.voiceButton) {
      this.voiceButton.disabled = loading
      this.sendButton?.setAttribute('disabled', loading ? 'true' : 'false')
    }
  }

  // ==================== Utilities ====================

  private getCSRFToken(): string {
    const token = document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement
    return token?.content || ''
  }

  private getExtension(): string {
    const mimeType = this.getSupportedMimeType()
    const map: Record<string, string> = {
      'audio/webm': 'webm',
      'audio/mp4': 'mp4',
      'audio/ogg': 'ogg'
    }
    return map[mimeType] || 'webm'
  }

  private escapeHtml(text: string): string {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
