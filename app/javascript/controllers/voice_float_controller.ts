import { Controller } from "@hotwired/stimulus"

// VoiceCommandEvent interface for ActionCable messages
interface VoiceCommandEvent {
  type: string
  command_text?: string
  response_text?: string
  command_type?: string
  error?: string
  video?: any
  content?: any
}

// Voice Float Controller - Handles the floating AI voice button
// Uses Turbo Stream architecture for frontend-backend interactions
export default class VoiceFloatController extends Controller {
  // Modal element reference (dynamically created)
  private modalElement: HTMLElement | null = null

  private recognition: any = null
  private isListening: boolean = false
  private isProcessing: boolean = false
  private channel: any = null
  private currentTranscript: string = ""
  private mediaRecorder: MediaRecorder | null = null
  private audioChunks: Blob[] = []
  private stream: MediaStream | null = null
  private recordingInterval: ReturnType<typeof setInterval> | null = null
  private wakeWordEnabled: boolean = false
  private wakePhrase: string = "hey autopilot"

  connect(): void {
    console.log("VoiceFloat controller connected")
    this.loadWakeWordSettings()
    this.ensureModalStructure()
  }

  disconnect(): void {
    console.log("VoiceFloat controller disconnected")
    this.stopListening()
    this.stopWakeWordDetection()
  }

  private loadWakeWordSettings(): void {
    const saved = localStorage.getItem('wake_word_enabled')
    this.wakeWordEnabled = saved === 'true'
    const savedPhrase = localStorage.getItem('wake_phrase')
    if (savedPhrase) {
      this.wakePhrase = savedPhrase.toLowerCase()
    }
  }

  toggle(event?: Event) {
    event?.preventDefault()
    if (this.isListening) {
      this.stopListening()
    } else {
      this.openModal()
    }
  }

  openModal() {
    this.ensureModalStructure()
    if (this.modalElement) {
      this.modalElement.classList.remove('hidden')
    }
    this.initializeActionCable()
    requestAnimationFrame(() => {
      if (this.modalElement) {
        this.modalElement.classList.add('flex')
      }
      setTimeout(() => {
        this.startListening()
      }, 300)
    })
  }

  closeModal() {
    this.stopListening()
    this.stopWakeWordDetection()
    if (this.channel) {
      this.channel.unsubscribe()
      this.channel = null
    }
    if (this.modalElement) {
      this.modalElement.classList.add('hidden')
      this.modalElement.classList.remove('flex')
    }
  }

  private getCurrentUserId(): string {
    // Try to get userId from various sources
    // 1. Check if voice-command interface exists with user-id
    const voiceCommand = document.querySelector('[data-voice-command-user-id-value]')
    if (voiceCommand) {
      const userId = voiceCommand.getAttribute('data-voice-command-user-id-value')
      if (userId) return userId
    }
    
    // 2. Check if any element has user-id data attribute
    const userIdElement = document.querySelector('[data-user-id]')
    if (userIdElement) {
      const userId = userIdElement.getAttribute('data-user-id')
      if (userId) return userId
    }
    
    // 3. Check meta tag (common pattern for authenticated apps)
    const userIdMeta = document.querySelector('meta[name="user-id"]')
    if (userIdMeta) {
      return userIdMeta.getAttribute('content') || 'anonymous'
    }
    
    // 4. Default to authenticated stream (user must be logged in)
    return 'authenticated'
  }

  private initializeActionCable() {
    const userId = this.getCurrentUserId()
    // For authenticated users, use voice_interaction_{userId}
    // For demo/unauthenticated, use a shared stream
    const streamName = userId !== 'anonymous' && userId !== 'authenticated' 
      ? `voice_interaction_${userId}` 
      : 'voice_interaction_demo'
    
    this.channel = (window as any).ActionCable.createConsumer().subscriptions.create(
      { channel: 'VoiceInteractionChannel', stream_name: streamName },
      {
        connected: () => {
          console.log('Voice channel connected to:', streamName)
          if (userId === 'authenticated') {
            console.log('Authenticated connection established (userId from session)')
          }
        },
        disconnected: () => console.log('Voice channel disconnected'),
        received: (data: VoiceCommandEvent) => this.handleChannelMessage(data)
      }
    )
  }

  private handleChannelMessage(data: VoiceCommandEvent): void {
    switch (data.type) {
      case 'command-received':
        this.updateTranscript(`Processing: ${data.command_text}`)
        break
      case 'command-completed':
        this.hideLoading()
        this.updateTranscript(data.response_text || 'Command completed!')
        this.showResult(data.response_text || 'Success!', data.command_type)
        this.isProcessing = false
        break
      case 'command-failed':
        this.hideLoading()
        this.updateTranscript(`Error: ${data.error || 'Command failed'}`)
        this.isProcessing = false
        break
      case 'video-generated':
        this.hideLoading()
        this.updateTranscript('Video generated successfully!')
        this.showResult('Video created!', 'video_generation', data.video)
        this.isProcessing = false
        break
      case 'content-generated':
        this.hideLoading()
        this.updateTranscript('Content generated successfully!')
        this.showResult('Content created!', 'content_generation', data.content)
        this.isProcessing = false
        break
    }
  }

  private ensureModalStructure() {
    if (document.getElementById('voice-float-modal')) return
    
    // Get userId from existing data attributes or check auth status
    const userId = this.getCurrentUserId()
    
    const modal = document.createElement('div')
    modal.id = 'voice-float-modal'
    modal.setAttribute('data-voice-float-user-id-value', userId)
    modal.className = "hidden fixed inset-0 z-[100] flex items-center justify-center"
    modal.innerHTML = `
      <div class="fixed inset-0 bg-black/50 backdrop-blur-sm"
           data-action="click->voice-float#closeModal"></div>
      <div class="relative bg-white rounded-3xl shadow-2xl p-8 max-w-md w-full mx-4
                  transform transition-all scale-95 opacity-0 voice-modal-content">
        <div class="text-center">
          <div class="w-24 h-24 mx-auto mb-6 rounded-full bg-gradient-to-br from-green-500
                      to-emerald-500 flex items-center justify-center shadow-lg animate-pulse
                      voice-icon-container">
            <svg class="w-12 h-12 text-white" fill="none" stroke="currentColor"
                 viewBox="0 0 24 24" id="voice-icon">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                    d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z">
              </path>
            </svg>
          </div>
          <h2 class="text-2xl font-bold text-primary mb-2">AI Voice Autopilot</h2>
          <p class="text-gray-600 mb-6">
            Speak your commands to create campaigns, generate content, and manage your social media
          </p>
          <div class="bg-gray-50 rounded-2xl p-4 mb-6 min-h-[100px] flex items-center justify-center">
            <p class="voice-transcript text-primary text-lg" id="voice-transcript">
              Click to start speaking...
            </p>
          </div>
          <div class="bg-blue-50 rounded-xl p-3 mb-6 text-left hidden" id="result-container">
            <p class="text-sm font-medium text-blue-900 mb-1">Result:</p>
            <p class="text-sm text-blue-700" id="result-text"></p>
          </div>
          <div class="bg-yellow-50 rounded-xl p-3 mb-6 text-left hidden" id="loading-container">
            <p class="text-sm text-yellow-700 flex items-center">
              <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-yellow-600" fill="none"
                   viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor"
                        stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z">
                </path>
              </svg>
              Processing your command...
            </p>
          </div>
          <button class="w-full py-3 bg-gradient-to-r from-green-500 to-emerald-500 text-white
                        font-semibold rounded-xl shadow-lg"
                  data-action="voice-float#closeModal">
            Close Voice Command
          </button>
        </div>
      </div>
    `
    document.body.appendChild(modal)
    this.modalElement = modal
    setTimeout(() => {
      modal.querySelector('.voice-modal-content')?.classList.remove('scale-95', 'opacity-0')
      modal.querySelector('.voice-modal-content')?.classList.add('scale-100', 'opacity-100')
    }, 10)
  }

  private startListening() {
    this.startWakeWordDetection()
  }

  private async startWakeWordDetection(): Promise<void> {
    if (!('MediaRecorder' in window) || !navigator.mediaDevices) {
      this.updateTranscript('Voice recording not supported')
      console.error('MediaRecorder or navigator.mediaDevices not available')
      return
    }
    
    console.log('Requesting microphone access...')
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: { 
          echoCancellation: true, 
          noiseSuppression: true, 
          autoGainControl: true,
          channelCount: 1
        }
      })
      console.log('Microphone access granted')
      this.isListening = true
      this.updateTranscript('Listening... Speak your command!')
      
      // Use opus codec for better quality if available
      const mimeType = MediaRecorder.isTypeSupported('audio/ogg;codecs=opus') 
        ? 'audio/ogg;codecs=opus'
        : 'audio/webm'
      
      console.log('Using mimeType:', mimeType)
      
      this.mediaRecorder = new MediaRecorder(this.stream, { mimeType, audioBitsPerSecond: 128000 })
      this.audioChunks = []
      
      // Always collect data - don't check size here
      // Store handlers for auto-restart
      const onDataAvailable = (event: any) => {
        if (event.data.size > 0) {
          console.log(`Audio chunk received: ${event.data.size} bytes`)
          this.audioChunks.push(event.data)
        }
      }
      
      const onError = (event: any) => {
        console.error('MediaRecorder error:', event.error)
      }
      
      const onStop = () => {
        console.log('MediaRecorder stopped, restarting...')
        if (this.isListening && this.stream) {
          try {
            this.mediaRecorder = new MediaRecorder(this.stream, { mimeType, audioBitsPerSecond: 128000 })
            this.mediaRecorder.ondataavailable = onDataAvailable
            this.mediaRecorder.onerror = onError
            this.mediaRecorder.onstop = onStop
            this.mediaRecorder.start(500)
            console.log('MediaRecorder restarted')
          } catch (_e) {
            console.log('Failed to restart MediaRecorder')
          }
        }
      }
      
      this.mediaRecorder.ondataavailable = onDataAvailable
      this.mediaRecorder.onerror = onError
      this.mediaRecorder.onstop = onStop
      
      // Start with 500ms timeslice
      this.mediaRecorder.start(500)
      console.log('MediaRecorder started (auto-restart enabled)')
      
      // Process buffered audio
      this.recordingInterval = setInterval(() => {
        if (this.isListening && this.audioChunks.length > 0) {
          this.processAudioWithWhisper()
        }
      }, 1000)
      
      this.updateIconState('listening')
    } catch (error) {
      console.error('Failed to start audio recording:', error)
      this.updateTranscript('Microphone access denied')
      this.isListening = false
    }
  }

  private stopWakeWordDetection(): void {
    this.isListening = false
    
    if (this.recordingInterval) {
      clearInterval(this.recordingInterval)
      this.recordingInterval = null
    }
    
    // Process any remaining audio before stopping
    if (this.audioChunks.length > 0) {
      console.log(`Processing final ${this.audioChunks.length} chunks before stopping`)
      this.processAudioWithWhisper()
    }
    
    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      try {
        this.mediaRecorder.stop()
        console.log('MediaRecorder stopped successfully')
      } catch (_e) {
        console.log('Error stopping MediaRecorder')
      }
      this.mediaRecorder = null
    }
    
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
      this.stream = null
    }
  }

  private stopListening() {
    this.stopWakeWordDetection()
    this.updateIconState('idle')
  }

  private processAudioWithWhisper(): void {
    if (this.audioChunks.length === 0) return
    
    // Combine all chunks into one audio blob
    const audioBlob = new Blob(this.audioChunks, { type: 'audio/webm' })
    this.audioChunks = []
    
    console.log(`Sending audio to Whisper: ${audioBlob.size} bytes`)
    
    // Process audio regardless of size - Whisper handles silence well
    if (audioBlob.size < 100) {
      console.log('Audio too small, keeping for next cycle')
      return
    }

    const formData = new FormData()
    formData.append('audio', audioBlob, 'audio.webm')
    formData.append('detect_wake_word', 'true')
    formData.append('wake_phrase', this.wakePhrase)

    // Use fetch for API endpoint - exempt from Turbo Stream requirements
    fetch('/api/v1/voice/transcribe', {
      method: 'POST',
      body: formData
    })
      .then(response => {
        console.log('Whisper API response status:', response.status)
        if (!response.ok) throw new Error(`Transcription failed: ${response.status}`)
        return response.json()
      })
      .then(data => {
        console.log('Whisper response:', data)
        if (data.text && data.text.trim().length > 0) {
          const cleanTranscript = data.text.replace(/^\s*[a-z]+\s*/i, '').trim()
          console.log('Clean transcript:', cleanTranscript)
          this.updateTranscript(cleanTranscript)
          
          if (data.wake_word_detected) {
            console.log('Wake word detected!')
            this.onWakeWordDetected()
          }
          
          // Process any transcript, not just long ones
          if (cleanTranscript.length > 0) {
            console.log('Processing command:', cleanTranscript)
            this.processCommand(cleanTranscript)
          }
        } else {
          console.log('No speech detected in audio')
        }
      })
      .catch(error => {
        console.error('Audio processing error:', error)
      })
  }

  private onWakeWordDetected(): void {
    console.log('Wake word detected!')
    const iconContainer = document.getElementById('voice-icon-container')
    if (iconContainer) {
      iconContainer.classList.remove('animate-pulse')
      void iconContainer.offsetWidth
      iconContainer.classList.add('animate-pulse')
    }
    this.playActivationSound()
  }

  private playActivationSound(): void {
    try {
      const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)()
      const oscillator = audioContext.createOscillator()
      const gainNode = audioContext.createGain()
      oscillator.connect(gainNode)
      gainNode.connect(audioContext.destination)
      oscillator.frequency.setValueAtTime(880, audioContext.currentTime)
      oscillator.type = 'sine'
      gainNode.gain.setValueAtTime(0.3, audioContext.currentTime)
      gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.3)
      oscillator.start()
      oscillator.stop(audioContext.currentTime + 0.3)
    } catch (_e) { /* ignore sound errors */ }
  }

  private updateIconState(state: 'listening' | 'processing' | 'idle') {
    const iconContainer = document.getElementById('voice-icon-container')
    const icon = document.getElementById('voice-icon')
    if (!iconContainer || !icon) return
    iconContainer.classList.remove('animate-pulse', 'bg-yellow-500', 'bg-green-500')
    const pathListening = '<path stroke-linecap="round" stroke-linejoin="round" ' +
      'stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"></path>'
    const pathProcessing = '<path stroke-linecap="round" stroke-linejoin="round" ' +
      'stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>'
    if (state === 'listening') {
      iconContainer.classList.add('animate-pulse', 'bg-green-500')
      icon.innerHTML = pathListening
    } else if (state === 'processing') {
      iconContainer.classList.add('animate-pulse', 'bg-yellow-500')
      icon.innerHTML = pathProcessing
    } else {
      iconContainer.classList.add('bg-green-500')
      icon.innerHTML = pathListening
    }
  }

  private updateTranscript(text: string) {
    const el = document.getElementById('voice-transcript')
    if (el) el.textContent = text
    if (text.toLowerCase().includes('wake word') ||
        text.toLowerCase().includes('hey autopilot')) {
      this.onWakeWordDetected()
    }
  }

  private processCommand(transcript: string) {
    this.currentTranscript = transcript
    this.isProcessing = true
    this.showLoading()
    if (this.channel) {
      // Send command to ActionCable for processing by AiAutopilotService
      this.channel.perform('process_voice_command', { command_text: transcript })
    }
  }

  private showLoading() {
    document.getElementById('loading-container')?.classList.remove('hidden')
    this.updateIconState('processing')
  }

  private hideLoading() {
    document.getElementById('loading-container')?.classList.add('hidden')
  }

  private showResult(text: string, _commandType?: string, _result?: any) {
    const container = document.getElementById('result-container')
    const resultText = document.getElementById('result-text')
    if (container && resultText) {
      resultText.textContent = text
      container.classList.remove('hidden')
    }
  }
}
