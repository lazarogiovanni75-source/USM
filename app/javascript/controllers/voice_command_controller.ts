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

  // Declare your targets and values
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
  private recognition: any
  private channel: any

  connect(): void {
    console.log("VoiceCommand connected")
    this.initializeVoiceRecognition()
    this.initializeActionCable()
  }

  disconnect(): void {
    console.log("VoiceCommand disconnected")
    if (this.recognition) {
      this.recognition.stop()
    }
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }

  // Voice recognition initialization
  private initializeVoiceRecognition(): void {
    if ('webkitSpeechRecognition' in window) {
      this.recognition = new (window as any).webkitSpeechRecognition()
      this.recognition.continuous = true
      this.recognition.interimResults = true
      this.recognition.lang = 'en-US'

      this.recognition.onstart = () => {
        this.updateMicrophoneStatus('Listening...', 'listening')
      }

      this.recognition.onresult = (event: any) => {
        this.handleSpeechResult(event)
      }

      this.recognition.onerror = (event: any) => {
        this.handleSpeechError(event)
      }

      this.recognition.onend = () => {
        this.updateMicrophoneStatus('Click to speak', 'idle')
        this.isRecording = false
      }
    } else {
      this.updateMicrophoneStatus('Voice recognition not supported', 'error')
    }
  }

  // ActionCable initialization
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

  // Handle speech recognition results
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

    // Update transcription display
    if (interimTranscript) {
      this.updateTranscription(finalTranscript, interimTranscript)
    }

    // If we have final transcript, process the command
    if (finalTranscript) {
      this.processVoiceCommand(finalTranscript.trim())
    }
  }

  // Handle speech recognition errors
  private handleSpeechError(event: any): void {
    console.error('Speech recognition error:', event.error)
    this.updateMicrophoneStatus(`Error: ${event.error}`, 'error')
    this.isRecording = false
  }

  // Update transcription display
  private updateTranscription(final: string, interim: string): void {
    const transcription = this.transcriptionContainerTarget
    transcription.innerHTML = `
      <div class="text-gray-600 text-sm">
        ${final ? `<div class="text-black font-medium mb-2">${final}</div>` : ''}
        ${interim ? `<div class="text-gray-500 italic">${interim}</div>` : ''}
      </div>
    `
  }

  // Process voice command
  private processVoiceCommand(commandText: string): void {
    if (this.isProcessing) return
    
    this.isProcessing = true
    this.showLoading()
    this.updateMicrophoneStatus('Processing...', 'processing')
    
    // Send command to server
    if (this.channel) {
      this.channel.perform('process_voice_command', {
        command_text: commandText
      })
    }
  }

  // Handle ActionCable messages
  private handleChannelMessage(data: VoiceCommandEvent): void {
    console.log('Received channel message:', data)
    
    switch (data.type) {
      case 'command-received':
        this.updateCommandHistory(data.command_text!, 'Processing')
        break
      case 'command-completed':
        this.hideLoading()
        this.updateCommandHistory(data.command_text!, 'Completed')
        this.updateAIResponse(data.response_text!, data.result, data.command_type!)
        this.isProcessing = false
        break
      case 'command-failed':
        this.hideLoading()
        this.updateCommandHistory(data.command_text!, 'Failed')
        this.showError(data.error!)
        this.isProcessing = false
        break
      case 'content-generated':
        this.updateAIResponse('Content generated successfully!', data.content, 'content_generated')
        break
      case 'campaign-created':
        this.updateAIResponse('Campaign created successfully!', data.campaign, 'campaign_created')
        break
      case 'generation-error':
      case 'campaign-error':
        this.showError(data.error!)
        break
    }
  }

  // Update command history
  private updateCommandHistory(command: string, status: string): void {
    const historyItem = document.createElement('div')
    historyItem.className = 'flex items-center justify-between p-3 bg-gray-50 rounded-lg mb-2'
    historyItem.innerHTML = `
      <div class="flex-1">
        <div class="text-sm font-medium text-gray-900">"${command}"</div>
        <div class="text-xs text-gray-500">${new Date().toLocaleTimeString()}</div>
      </div>
      <div class="px-2 py-1 text-xs rounded-full ${
  status === 'Completed' ? 'bg-green-100 text-green-800' :
    status === 'Processing' ? 'bg-yellow-100 text-yellow-800' :
      status === 'Failed' ? 'bg-red-100 text-red-800' :
        'bg-gray-100 text-gray-800'
}">
        ${status}
      </div>
    `
    
    this.commandHistoryTarget.prepend(historyItem)
  }

  // Update AI response display
  private updateAIResponse(response: string, result: any, commandType: string): void {
    const responseContainer = this.aiResponseContainerTarget
    responseContainer.innerHTML = `
      <div class="bg-white border border-gray-200 rounded-lg p-6 shadow-sm">
        <div class="flex items-center mb-4">
          <div class="w-8 h-8 bg-gradient-to-r from-purple-500 to-blue-500 rounded-full flex items-center justify-center mr-3">
            <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-gray-900">AI Autopilot Response</h3>
        </div>
        
        <div class="text-gray-700 mb-4">${response}</div>
        
        ${this.formatCommandResult(result, commandType)}
        
        <div class="mt-4 pt-4 border-t border-gray-100">
          <div class="text-xs text-gray-500">
            Command Type: <span class="font-medium">${commandType.replace('_', ' ')}</span>
          </div>
        </div>
      </div>
    `
  }

  // Format command result based on type
  private formatCommandResult(result: any, commandType: string): string {
    if (!result) return ''
    
    switch (commandType) {
      case 'content_generated':
        if (result.title) {
          return `
            <div class="bg-gray-50 p-4 rounded-lg mt-4">
              <h4 class="font-medium text-gray-900 mb-2">Generated Content:</h4>
              <p class="text-sm text-gray-600">${result.title}</p>
              ${result.body ? `<p class="text-sm text-gray-600 mt-2">${result.body}</p>` : ''}
              ${result.platform ? `<span class="inline-block px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded mt-2">${result.platform}</span>` : ''}
            </div>
          `
        }
        break
      case 'campaign_created':
        if (result.name) {
          return `
            <div class="bg-gray-50 p-4 rounded-lg mt-4">
              <h4 class="font-medium text-gray-900 mb-2">New Campaign:</h4>
              <p class="text-sm text-gray-600">${result.name}</p>
              ${result.description ? `<p class="text-sm text-gray-600 mt-2">${result.description}</p>` : ''}
              <div class="flex items-center mt-3 space-x-4">
                ${result.budget ? `<span class="text-xs bg-green-100 text-green-800 px-2 py-1 rounded">$${result.budget}</span>` : ''}
                ${result.status ? `<span class="text-xs bg-gray-100 text-gray-800 px-2 py-1 rounded">${result.status}</span>` : ''}
              </div>
            </div>
          `
        }
        break
    }
    
    return `
      <div class="bg-gray-50 p-4 rounded-lg mt-4">
        <pre class="text-sm text-gray-600 whitespace-pre-wrap">${JSON.stringify(result, null, 2)}</pre>
      </div>
    `
  }

  // Show loading state
  private showLoading(): void {
    this.loadingIndicatorTarget.classList.remove('hidden')
  }

  // Hide loading state
  private hideLoading(): void {
    this.loadingIndicatorTarget.classList.add('hidden')
  }

  // Show error message
  private showError(error: string): void {
    const errorContainer = this.aiResponseContainerTarget
    errorContainer.innerHTML = `
      <div class="bg-red-50 border border-red-200 rounded-lg p-6">
        <div class="flex items-center">
          <div class="w-8 h-8 bg-red-100 rounded-full flex items-center justify-center mr-3">
            <svg class="w-4 h-4 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
          </div>
          <div>
            <h3 class="text-lg font-semibold text-red-800">Error</h3>
            <p class="text-red-700">${error}</p>
          </div>
        </div>
      </div>
    `
  }

  // Update microphone status
  private updateMicrophoneStatus(status: string, state: string): void {
    this.microphoneStatusTarget.textContent = status
    this.microphoneStatusTarget.className = `text-sm font-medium ${
      state === 'listening' ? 'text-green-600' :
        state === 'processing' ? 'text-blue-600' :
          state === 'error' ? 'text-red-600' :
            'text-gray-600'
    }`
  }

  // Action methods
  toggleRecording(): void {
    if (!this.recognition) return
    
    if (this.isRecording) {
      this.recognition.stop()
      this.isRecording = false
    } else {
      this.recognition.start()
      this.isRecording = true
    }
  }

  clearHistory(): void {
    this.commandHistoryTarget.innerHTML = ''
    this.aiResponseContainerTarget.innerHTML = ''
    this.transcriptionContainerTarget.innerHTML = ''
  }

  generateQuickContent(): void {
    if (this.channel) {
      this.channel.perform('generate_content', {
        content_type: 'post',
        platform: 'general'
      })
    }
  }

  createQuickCampaign(): void {
    if (this.channel) {
      const campaignData = {
        name: 'Quick Campaign',
        description: 'Campaign created via voice command',
        target_audience: 'General Audience',
        budget: 1000,
        start_date: new Date().toISOString().split('T')[0],
        end_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
      }
      
      this.channel.perform('create_campaign', {
        campaign_data: campaignData
      })
    }
  }
}
