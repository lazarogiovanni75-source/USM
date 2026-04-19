import { Controller } from "@hotwired/stimulus"

interface VoiceCommandEvent {
  type: string
  voice_command_id?: number
  command_text?: string
  status?: string
  response_text?: string
  command_type?: string
  result?: any
  error?: string
  timestamp?: string
  campaign?: any
  content?: any
  audio_url?: string
}

export default class extends Controller<HTMLElement> {
  static targets = [
    "voiceButton",
    "transcriptionContainer",
    "commandHistory",
    "aiResponseContainer",
    "loadingIndicator",
    "microphoneStatus"
  ]

  static values = {
    userId: String,
    channelName: String
  }

  declare readonly voiceButtonTarget: HTMLButtonElement
  declare readonly transcriptionContainerTarget: HTMLElement
  declare readonly commandHistoryTarget: HTMLElement
  declare readonly aiResponseContainerTarget: HTMLElement
  declare readonly loadingIndicatorTarget: HTMLElement
  declare readonly microphoneStatusTarget: HTMLElement
  declare readonly userIdValue: string
  declare readonly channelNameValue: string

  private isRecording = false
  private isProcessing = false
  private shouldKeepListening = false
  private recognition: any
  private channel: any
  private restartTimeout: any = null
  private retryCount = 0
  private maxRetries = 2

  connect(): void {
    console.log("VoiceCommand connected")
    this.initializeVoiceRecognition()
    this.initializeActionCable()
  }

  disconnect(): void {
    console.log("VoiceCommand disconnected")
    if (this.restartTimeout) {
      clearTimeout(this.restartTimeout)
    }
    if (this.recognition) {
      try {
        this.recognition.stop()
      } catch (e) {
        console.log('Recognition already stopped')
      }
    }
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }

  private initializeVoiceRecognition(): void {
    if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
      const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
      this.recognition = new SpeechRecognition()
      this.recognition.continuous = true
      this.recognition.interimResults = true
      this.recognition.lang = 'en-US'
      this.recognition.maxAlternatives = 1

      this.recognition.onstart = () => {
        this.isRecording = true
        this.shouldKeepListening = true
        this.updateMicrophoneStatus('Listening...', 'listening')
      }

      this.recognition.onresult = (event: any) => {
        this.handleSpeechResult(event)
      }

      this.recognition.onerror = (event: any) => {
        console.error('Speech recognition error:', event.error)
        
        const nonFatalErrors = ['no-speech', 'aborted', 'audio-capture', 'network', 'not-allowed']
        
        if (nonFatalErrors.includes(event.error)) {
          this.retryCount = 0 // Reset retry count on non-fatal errors
          if (this.shouldKeepListening && !this.isProcessing) {
            this.scheduleRestart()
          }
          return
        }
        
        // Retry logic for other errors
        if (this.retryCount < this.maxRetries) {
          this.retryCount++
          console.log(`Retrying speech recognition (${this.retryCount}/${this.maxRetries})`)
          this.updateMicrophoneStatus(`Retrying... (${this.retryCount}/${this.maxRetries})`, 'processing')
          this.scheduleRestart()
        } else {
          this.updateMicrophoneStatus(`Error: ${event.error}`, 'error')
          this.isRecording = false
          this.shouldKeepListening = false
          this.retryCount = 0
        }
      }

      this.recognition.onend = () => {
        console.log('Speech recognition ended, shouldKeepListening:', this.shouldKeepListening)
        
        if (this.shouldKeepListening && !this.isProcessing) {
          // Restart immediately - no delay
          this.scheduleRestart()
        } else {
          this.updateMicrophoneStatus('Click to speak', 'idle')
          this.isRecording = false
        }
      }
    } else {
      this.updateMicrophoneStatus('Voice not supported', 'error')
    }
  }

  private scheduleRestart(): void {
    if (this.restartTimeout) {
      clearTimeout(this.restartTimeout)
    }
    
    // Restart as fast as possible
    this.restartTimeout = setTimeout(() => {
      try {
        this.recognition.start()
        this.isRecording = true
        this.updateMicrophoneStatus('Listening...', 'listening')
      } catch (e) {
        console.error('Failed to restart:', e)
        // Try again after short delay
        this.restartTimeout = setTimeout(() => {
          try {
            this.recognition.start()
            this.isRecording = true
            this.updateMicrophoneStatus('Listening...', 'listening')
          } catch (e2) {
            console.error('Failed to restart on second try:', e2)
            this.updateMicrophoneStatus('Click to speak', 'idle')
          }
        }, 200)
      }
    }, 50) // Very short delay
  }

  private initializeActionCable(): void {
    const channelName = this.channelNameValue || `voice_interaction_${this.userIdValue}`
    this.channel = (window as any).ActionCable.createConsumer().subscriptions.create(
      { channel: 'VoiceInteractionChannel', stream_name: channelName },
      {
        connected: () => {
          console.log('Voice interaction channel connected')
        },
        disconnected: () => {
          console.log('Voice interaction channel disconnected')
        },
        received: (data: VoiceCommandEvent) => {
          this.handleChannelMessage(data)
        }
      }
    )
  }

  private handleSpeechResult(event: any): void {
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

    if (interimTranscript) {
      this.updateTranscription(finalTranscript, interimTranscript)
    }

    if (finalTranscript) {
      console.log('Final transcript received:', finalTranscript)
      this.stopRecognitionForProcessing()
      this.processVoiceCommand(finalTranscript.trim())
    }
  }

  private stopRecognitionForProcessing(): void {
    this.shouldKeepListening = false
    try {
      this.recognition.stop()
    } catch (e) {
      console.log('Recognition already stopped')
    }
    this.isRecording = false
  }

  private updateTranscription(final: string, interim: string): void {
    const transcription = this.transcriptionContainerTarget
    transcription.innerHTML = `
      <div class="text-gray-600 text-sm">
        ${final ? `<div class="text-black font-medium mb-2">${final}</div>` : ''}
        ${interim ? `<div class="text-gray-500 italic">${interim}</div>` : ''}
      </div>
    `
  }

  private processVoiceCommand(commandText: string): void {
    if (this.isProcessing) return
    
    this.isProcessing = true
    this.showLoading()
    this.updateMicrophoneStatus('Processing...', 'processing')
    
    if (this.channel) {
      this.channel.perform('process_voice_command', {
        command_text: commandText
      })
    }
  }

  private handleChannelMessage(data: VoiceCommandEvent): void {
    console.log('Received channel message:', data)
    
    switch (data.type) {
      case 'command-received':
        this.updateCommandHistory(data.command_text!, 'Processing')
        break
      case 'complete':
        this.hideLoading()
        this.updateCommandHistory(data.command_text!, 'Completed')
        this.updateAIResponse(data.content || data.response_text, data.result, data.command_type)
        
        // Play TTS audio if available
        if (data.audio_url) {
          this.playTTSAudio(data.audio_url)
        }
        
        this.isProcessing = false
        this.autoRestartListening()
        break
      case 'command-failed':
        this.hideLoading()
        this.updateCommandHistory(data.command_text!, 'Failed')
        this.showError(data.error!)
        this.isProcessing = false
        this.updateMicrophoneStatus('Click to speak', 'idle')
        break
      case 'content-generated':
        this.updateAIResponse('Content generated!', data.content, 'content_generated')
        this.isProcessing = false
        this.autoRestartListening()
        break
      case 'campaign-created':
        this.updateAIResponse('Campaign created!', data.campaign, 'campaign_created')
        this.isProcessing = false
        this.autoRestartListening()
        break
      case 'generation-error':
      case 'campaign-error':
        this.showError(data.error!)
        this.isProcessing = false
        this.updateMicrophoneStatus('Click to speak', 'idle')
        break
    }
  }

  private playTTSAudio(audioUrl: string): void {
    console.log('Playing TTS audio:', audioUrl)
    
    const audio = new Audio(audioUrl)
    audio.play().catch(err => {
      console.error('TTS playback error:', err)
    })
  }

  private autoRestartListening(): void {
    this.updateMicrophoneStatus('Restarting...', 'processing')
    this.retryCount = 0 // Reset retry count after successful command
    
    // Immediate restart after response
    this.restartTimeout = setTimeout(() => {
      try {
        this.recognition.start()
        this.shouldKeepListening = true
        this.isRecording = true
        this.updateMicrophoneStatus('Listening...', 'listening')
        console.log('Auto-restarted listening after response')
      } catch (e) {
        console.error('Failed to auto-restart:', e)
        this.updateMicrophoneStatus('Click to speak', 'idle')
      }
    }, 300)
  }

  private updateMicrophoneStatus(message: string, status: string): void {
    const statusEl = this.microphoneStatusTarget
    if (statusEl) {
      statusEl.textContent = message
      statusEl.className = `text-xs mt-1 ${
        status === 'listening' ? 'text-green-600' :
          status === 'processing' ? 'text-blue-600' :
            status === 'error' ? 'text-red-600' :
              'text-gray-500'
      }`
    }
  }

  private showLoading(): void {
    const loading = this.loadingIndicatorTarget
    if (loading) loading.classList.remove('hidden')
  }

  private hideLoading(): void {
    const loading = this.loadingIndicatorTarget
    if (loading) loading.classList.add('hidden')
  }

  private updateCommandHistory(text: string, status: string): void {
    const history = this.commandHistoryTarget
    if (history) {
      const entry = document.createElement('div')
      entry.className = 'border-b py-2 text-sm'
      entry.innerHTML = `
        <div class="flex justify-between">
          <span class="font-medium">${text}</span>
          <span class="${status === 'Completed' ? 'text-green-600' : status === 'Failed' ? 'text-red-600' : 'text-yellow-600'}">${status}</span>
        </div>
      `
      history.insertBefore(entry, history.firstChild)
    }
  }

  private updateAIResponse(text: string, result: any, commandType: string): void {
    const container = this.aiResponseContainerTarget
    if (container) {
      let resultHtml = ''
      
      if (commandType === 'campaign_created' && result) {
        resultHtml = `
          <div class="mt-2 p-2 bg-green-50 rounded text-sm">
            <strong>Campaign:</strong> ${result.name || 'Unnamed'}<br>
            <strong>Status:</strong> ${result.status || 'draft'}
          </div>
        `
      } else if (commandType === 'content_generated' && result) {
        resultHtml = `
          <div class="mt-2 p-2 bg-blue-50 rounded text-sm">
            <strong>Content created:</strong> ${result.title || 'Untitled'}
          </div>
        `
      }
      
      container.innerHTML = `
        <div class="p-3 bg-gray-50 rounded-lg">
          <div class="text-sm text-gray-800">${text}</div>
          ${resultHtml}
        </div>
      `
    }
  }

  private showError(message: string): void {
    const container = this.aiResponseContainerTarget
    if (container) {
      container.innerHTML = `
        <div class="p-3 bg-red-50 rounded-lg">
          <div class="text-sm text-red-800">Error: ${message}</div>
        </div>
      `
    }
  }

  // Public method - toggle voice recording
  toggleVoice(): void {
    if (this.isRecording) {
      this.stopRecognition()
    } else {
      this.startRecognition()
    }
  }

  private startRecognition(): void {
    if (!this.recognition) {
      this.updateMicrophoneStatus('Voice not supported', 'error')
      return
    }
    
    try {
      this.shouldKeepListening = true
      this.recognition.start()
      this.updateMicrophoneStatus('Starting...', 'processing')
    } catch (e) {
      console.error('Failed to start recognition:', e)
      this.updateMicrophoneStatus('Click to speak', 'idle')
    }
  }

  private stopRecognition(): void {
    this.shouldKeepListening = false
    try {
      this.recognition.stop()
    } catch (e) {
      console.log('Recognition already stopped')
    }
    this.isRecording = false
    this.updateMicrophoneStatus('Click to speak', 'idle')
  }

  clearHistory(): void {
    const history = this.commandHistoryTarget
    if (history) {
      history.innerHTML = ''
    }
  }

  toggleRecording(): void {
    if (this.isRecording) {
      this.stopRecognition()
    } else {
      this.startRecognition()
    }
  }

  generateQuickContent(): void {
    const commandText = 'generate content about marketing'
    this.processVoiceCommand(commandText)
  }

  createQuickCampaign(): void {
    const commandText = 'create campaign for social media'
    this.processVoiceCommand(commandText)
  }
}
