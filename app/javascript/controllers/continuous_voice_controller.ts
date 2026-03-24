import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

// Voice State Machine States
type VoiceState = 
  | 'IDLE'
  | 'LISTENING'
  | 'TRANSCRIBING'
  | 'GENERATING'
  | 'AWAITING_CONFIRMATION'
  | 'EXECUTING_TOOL'
  | 'SPEAKING'

// Standardized Event Types from Backend
interface VoiceEvent {
  type: string
  conversation_id?: string
  execution_id?: string
  timestamp?: number
  payload: {
    content?: string
    text?: string
    tool?: string
    arguments?: Record<string, any>
    result?: any
    error?: string
    requiresConfirmation?: boolean
    confirmed?: boolean
  }
}

export default class extends Controller<HTMLElement> {
  static targets = [
    "voiceButton",
    "status",
    "transcription",
    "response"
  ]

  static values = {
    userId: String,
    conversationId: String
  }

  declare readonly voiceButtonTarget: HTMLButtonElement
  declare readonly statusTarget: HTMLElement
  declare readonly transcriptionTarget: HTMLElement
  declare readonly responseTarget: HTMLElement
  declare readonly userIdValue: string
  declare readonly conversationIdValue: string

  private mediaRecorder: MediaRecorder | null = null
  private audioChunks: Blob[] = []
  private stream: MediaStream | null = null
  private audioContext: AudioContext | null = null
  private analyser: AnalyserNode | null = null
  private cableSubscription: any = null
  
  // State Machine
  private state: VoiceState = 'IDLE'
  private stateHistory: VoiceState[] = []

  // Pause detection for early GPT trigger
  private lastAudioTime = 0
  private silenceTimer: ReturnType<typeof setTimeout> | null = null
  private silenceThreshold = 700
  private minChunkDuration = 300
  private pendingAudio: Blob[] = []
  private isTranscribing = false

  // Execution tracking
  private currentExecutionId: string | null = null
  private pendingConfirmation: { tool: string; args: Record<string, any>; executionId: string } | null = null

  // Allowed state transitions
  private readonly stateTransitions: Record<VoiceState, VoiceState[]> = {
    'IDLE': ['LISTENING'],
    'LISTENING': ['TRANSCRIBING', 'IDLE'],
    'TRANSCRIBING': ['GENERATING', 'LISTENING', 'IDLE'],
    'GENERATING': ['AWAITING_CONFIRMATION', 'EXECUTING_TOOL', 'SPEAKING', 'LISTENING', 'IDLE'],
    'AWAITING_CONFIRMATION': ['EXECUTING_TOOL', 'LISTENING', 'IDLE'],
    'EXECUTING_TOOL': ['SPEAKING', 'GENERATING', 'LISTENING', 'IDLE'],
    'SPEAKING': ['LISTENING', 'IDLE']
  }

  connect(): void {
    console.log("ContinuousVoice controller connected")
    this.setState('IDLE')
    this.updateStatusUI()
    this.subscribeToCable()
  }

  disconnect(): void {
    this.stopRecording()
    this.cableSubscription?.unsubscribe()
  }

  // State Machine Methods
  private canTransitionTo(newState: VoiceState): boolean {
    return this.stateTransitions[this.state]?.includes(newState) || false
  }

  private setState(newState: VoiceState): void {
    if (this.state === newState) return

    const oldState = this.state
    console.log(`[VoiceState] ${oldState} -> ${newState}`)

    this.stateHistory.push(this.state)
    if (this.stateHistory.length > 10) {
      this.stateHistory.shift()
    }

    this.state = newState
    this.updateStatusUI()
  }

  private isLocked(): boolean {
    return ['TRANSCRIBING', 'GENERATING', 'AWAITING_CONFIRMATION', 'EXECUTING_TOOL', 'SPEAKING'].includes(this.state)
  }

  private updateStatusUI(): void {
    const statusMessages: Record<VoiceState, string> = {
      'IDLE': 'Click microphone to start',
      'LISTENING': '🎙️ Listening...',
      'TRANSCRIBING': '⏳ Transcribing...',
      'GENERATING': '🤔 Thinking...',
      'AWAITING_CONFIRMATION': '❓ Awaiting confirmation...',
      'EXECUTING_TOOL': '⚙️ Executing task...',
      'SPEAKING': '🔊 Speaking...'
    }

    const statusColors: Record<VoiceState, string> = {
      'IDLE': 'text-gray-500',
      'LISTENING': 'text-green-600',
      'TRANSCRIBING': 'text-blue-600',
      'GENERATING': 'text-purple-600',
      'AWAITING_CONFIRMATION': 'text-yellow-600',
      'EXECUTING_TOOL': 'text-orange-600',
      'SPEAKING': 'text-blue-600'
    }

    this.statusTarget.textContent = statusMessages[this.state]
    this.statusTarget.className = `text-sm mt-2 ${statusColors[this.state]}`

    // Update voice button visual state
    this.voiceButtonTarget.classList.toggle('recording', this.state === 'LISTENING')
    this.voiceButtonTarget.classList.toggle('processing', ['TRANSCRIBING', 'GENERATING', 'EXECUTING_TOOL'].includes(this.state))
    this.voiceButtonTarget.disabled = this.isLocked()
  }

  // Cable Subscription
  private subscribeToCable(): void {
    // Use proper ActionCable subscription format with channel class
    this.cableSubscription = consumer.subscriptions.create(
      { channel: "VoiceInteractionChannel", user_id: this.userIdValue },
      {
        received: (data: any) => {
          this.handleCableMessage(data)
        }
      }
    )
    console.log("Subscribed to voice channel: VoiceInteractionChannel for user", this.userIdValue)
  }

  // Handle standardized event contract
  private handleCableMessage(data: VoiceEvent): void {
    console.log('[VoiceEvent]', data.type, data.payload)

    switch (data.type) {
      case 'transcript_partial':
        this.handleTranscriptPartial(data.payload)
        break
      case 'transcript_final':
        this.handleTranscriptFinal(data.payload)
        break
      case 'assistant_token':
        this.handleAssistantToken(data.payload)
        break
      case 'assistant_complete':
        this.handleAssistantComplete(data.payload)
        break
      case 'tool_call_detected':
        this.handleToolCallDetected(data.execution_id!, data.payload)
        break
      case 'awaiting_confirmation':
        this.handleAwaitingConfirmation(data.execution_id!, data.payload)
        break
      case 'confirmation_received':
        this.handleConfirmationReceived(data.payload)
        break
      case 'tool_execution_started':
        this.handleToolExecutionStarted(data.payload)
        break
      case 'tool_execution_completed':
        this.handleToolExecutionCompleted(data.payload)
        break
      case 'tool_execution_failed':
        this.handleToolExecutionFailed(data.payload)
        break
      case 'execution_cancelled':
        this.handleExecutionCancelled(data.payload)
        break
      case 'error':
        this.handleError(data.payload)
        break
      default:
        console.warn('[VoiceEvent] Unknown type:', data.type)
    }
  }

  // Event Handlers
  private handleTranscriptPartial(payload: VoiceEvent['payload']): void {
    if (payload.text) {
      this.transcriptionTarget.innerHTML = `<div class="text-gray-500">${payload.text}</div>`
    }
  }

  private handleTranscriptFinal(payload: VoiceEvent['payload']): void {
    if (payload.text) {
      this.transcriptionTarget.innerHTML = `<div class="text-lg font-medium text-gray-900">${payload.text}</div>`
    }
    this.setState('GENERATING')
  }

  private handleAssistantToken(payload: VoiceEvent['payload']): void {
    if (payload.content) {
      const responseEl = this.responseTarget.querySelector('.response-content')
      if (responseEl) {
        responseEl.textContent += payload.content
      } else {
        this.responseTarget.innerHTML = `<div class="response-content text-gray-800"></div>`
        const newEl = this.responseTarget.querySelector('.response-content')
        if (newEl) newEl.textContent = payload.content
      }
    }
  }

  private handleAssistantComplete(payload: VoiceEvent['payload']): void {
    this.currentExecutionId = null
    this.setState('SPEAKING')
    
    // After speaking, go back to listening
    setTimeout(() => {
      if (this.state === 'SPEAKING') {
        this.setState('LISTENING')
        if (!this.isRecording) {
          this.startRecording()
        }
      }
    }, 2000)
  }

  private handleToolCallDetected(executionId: string, payload: VoiceEvent['payload']): void {
    this.currentExecutionId = executionId
    this.setState('EXECUTING_TOOL')
    
    // Show tool being executed
    this.responseTarget.innerHTML = `
      <div class="p-3 bg-blue-50 rounded-lg">
        <div class="text-sm text-blue-600">⚙️ Executing: ${payload.tool}</div>
      </div>
    `
  }

  private handleAwaitingConfirmation(executionId: string, payload: VoiceEvent['payload']): void {
    this.setState('AWAITING_CONFIRMATION')
    this.pendingConfirmation = {
      tool: payload.tool || '',
      args: payload.arguments || {},
      executionId
    }

    // Show confirmation dialog
    this.responseTarget.innerHTML = `
      <div class="p-4 bg-yellow-50 rounded-lg border border-yellow-200">
        <div class="text-yellow-800 font-medium">Confirm: ${payload.tool}?</div>
        <div class="text-sm text-yellow-600 mt-1">Say "yes" to confirm or "no" to cancel</div>
      </div>
    `
  }

  private handleConfirmationReceived(payload: VoiceEvent['payload']): void {
    if (payload.confirmed) {
      this.setState('EXECUTING_TOOL')
    } else {
      this.setState('LISTENING')
      this.pendingConfirmation = null
    }
  }

  private handleToolExecutionStarted(payload: VoiceEvent['payload']): void {
    this.setState('EXECUTING_TOOL')
    this.responseTarget.innerHTML += `
      <div class="text-sm text-gray-500 mt-2">▶️ Started: ${payload.tool}</div>
    `
  }

  private handleToolExecutionCompleted(payload: VoiceEvent['payload']): void {
    // Show result
    const result = payload.result
    let resultHtml = ''
    
    if (result.status === 'success') {
      resultHtml = `
        <div class="mt-3 p-3 bg-green-50 rounded-lg">
          <div class="text-green-800">✅ ${result.message}</div>
          ${result.data?.image_url ? `<img src="${result.data.image_url}" class="mt-2 rounded-lg max-w-xs" />` : ''}
          ${result.data?.video_id ? `<div class="text-sm text-green-600 mt-1">Video ID: ${result.data.video_id}</div>` : ''}
          ${result.data?.post_id ? `<div class="text-sm text-green-600 mt-1">Post ID: ${result.data.post_id}</div>` : ''}
        </div>
      `
    } else {
      resultHtml = `
        <div class="mt-3 p-3 bg-red-50 rounded-lg">
          <div class="text-red-800">❌ ${result.error || result.message}</div>
        </div>
      `
    }

    this.responseTarget.innerHTML += resultHtml
    
    // Continue to next tool or finish
    this.setState('GENERATING')
  }

  private handleToolExecutionFailed(payload: VoiceEvent['payload']): void {
    this.responseTarget.innerHTML += `
      <div class="mt-3 p-3 bg-red-50 rounded-lg">
        <div class="text-red-800">❌ Failed: ${payload.error}</div>
      </div>
    `
    this.setState('LISTENING')
  }

  private handleExecutionCancelled(payload: VoiceEvent['payload']): void {
    this.pendingConfirmation = null
    this.currentExecutionId = null
    this.setState('LISTENING')
  }

  private handleError(payload: VoiceEvent['payload']): void {
    this.responseTarget.innerHTML = `
      <div class="p-3 bg-red-50 rounded-lg">
        <div class="text-red-800">Error: ${payload.error}</div>
      </div>
    `
    this.setState('IDLE')
  }

  // Recording Methods
  async toggleRecording() {
    if (this.isLocked()) {
      console.log('[VoiceState] Cannot toggle - locked in', this.state)
      return
    }

    if (this.state === 'LISTENING') {
      this.stopRecording()
    } else if (this.state === 'IDLE') {
      await this.startRecording()
    }
  }

  async startRecording() {
    if (!this.canTransitionTo('LISTENING')) {
      console.log('[VoiceState] Cannot start recording from', this.state)
      return
    }

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ 
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        } 
      })

      this.audioContext = new AudioContext()
      this.analyser = this.audioContext.createAnalyser()
      const source = this.audioContext.createMediaStreamSource(this.stream)
      source.connect(this.analyser)

      this.mediaRecorder = new MediaRecorder(this.stream, {
        mimeType: 'audio/webm;codecs=opus'
      })

      this.audioChunks = []

      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.audioChunks.push(event.data)
          this.lastAudioTime = Date.now()
          this.checkForSilence()
        }
      }

      this.mediaRecorder.onstop = () => {
        this.processAudio()
      }

      this.mediaRecorder.start(300)
      this.setState('LISTENING')
      this.lastAudioTime = Date.now()
      this.pendingAudio = []
      
      console.log("Started continuous recording")
      
    } catch (error: any) {
      console.error("Failed to start recording:", error)
      this.handleError({ error: error.message })
    }
  }

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      this.mediaRecorder.stop()
    }
    
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
      this.stream = null
    }

    if (this.audioContext) {
      this.audioContext.close()
      this.audioContext = null
    }

    if (this.silenceTimer) {
      clearTimeout(this.silenceTimer)
      this.silenceTimer = null
    }

    if (this.state === 'LISTENING') {
      this.setState('IDLE')
    }
  }

  private checkForSilence(): void {
    if (this.silenceTimer) {
      clearTimeout(this.silenceTimer)
    }
    
    this.silenceTimer = setTimeout(() => {
      const silenceDuration = Date.now() - this.lastAudioTime
      
      if (silenceDuration >= this.silenceThreshold && this.audioChunks.length > 0) {
        this.processAudio(true)
      }
    }, this.silenceThreshold)
  }

  private async processAudio(isEarlyTrigger = false) {
    if (this.isLocked()) {
      console.log('[VoiceState] Skipping processAudio - locked in', this.state)
      return
    }

    if (this.audioChunks.length === 0) {
      if (this.state === 'LISTENING') {
        setTimeout(() => this.startRecording(), 100)
      }
      return
    }

    this.setState('TRANSCRIBING')

    const audioBlob = new Blob(this.audioChunks, { type: 'audio/webm' })
    this.audioChunks = []
    this.pendingAudio = []

    try {
      const formData = new FormData()
      formData.append('audio', audioBlob, 'audio.webm')
      formData.append('detect_wake_word', 'false')
      formData.append('early_trigger', isEarlyTrigger.toString())
      formData.append('conversation_id', this.conversationIdValue || '')
      formData.append('stream_name', `voice_interaction_${this.userIdValue}`)

      const response = await fetch('/api/v1/voice/stream', {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': this.getCSRFToken()
        }
      })

      const data = await response.json()

      if (data.error) {
        this.handleError({ error: data.error })
      } else if (data.text) {
        this.transcriptionTarget.innerHTML = `
          <div class="text-lg font-medium text-gray-900">${data.text}</div>
        `
        this.responseTarget.innerHTML = ''
        this.setState('GENERATING')
      }

    } catch (error: any) {
      console.error("Transcription error:", error)
      this.handleError({ error: error.message })
    }

    // Restart recording for continuous conversation
    if (this.state !== 'IDLE') {
      setTimeout(() => {
        if (!this.isRecording && this.state !== 'IDLE') {
          this.startRecording()
        }
      }, 100)
    }
  }

  // Handle yes/no for confirmation
  handleConfirmation(confirmed: boolean): void {
    if (this.state !== 'AWAITING_CONFIRMATION') {
      console.log('[VoiceState] No pending confirmation')
      return
    }

    if (confirmed) {
      this.setState('EXECUTING_TOOL')
    } else {
      this.setState('LISTENING')
      this.pendingConfirmation = null
    }
  }

  // Cancel current execution
  cancel(): void {
    if (this.isLocked()) {
      this.setState('IDLE')
      this.stopRecording()
    }
  }

  private get isRecording(): boolean {
    return this.mediaRecorder?.state === 'recording'
  }

  private getCSRFToken(): string {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') || '' : ''
  }
}
