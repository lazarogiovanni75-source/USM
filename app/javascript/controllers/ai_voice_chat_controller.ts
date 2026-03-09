import { Controller } from "@hotwired/stimulus"

// AI Voice Chat Controller - Uses browser's webkitSpeechRecognition
export default class AiVoiceChatController extends Controller {
  // stimulus-validator: disable-next-line
  static targets = ["button", "indicator", "status", "transcript"]
  
  // stimulus-validator: disable-next-line
  declare readonly buttonTarget: HTMLButtonElement
  // stimulus-validator: disable-next-line
  declare readonly indicatorTarget: HTMLElement
  // stimulus-validator: disable-next-line
  declare readonly statusTarget: HTMLElement
  // stimulus-validator: disable-next-line
  declare readonly transcriptTarget: HTMLElement
  
  private recognition: any = null
  private isRecording: boolean = false
  private isProcessing: boolean = false
  private shouldBeListening: boolean = false
  
  connect(): void {
    this.initializeSpeechRecognition()
    console.log("AI Voice Chat controller connected")
  }
  
  disconnect(): void {
    this.stopListening()
  }
  
  private initializeSpeechRecognition(): void {
    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
    
    if (!SpeechRecognition) {
      console.warn('Speech recognition not supported in this browser')
      this.updateStatus('Voice not supported')
      const buttonEl = document.querySelector('[data-ai-voice-chat-target="button"]') as HTMLButtonElement;
      buttonEl?.setAttribute('disabled', 'true')
      return
    }
    
    this.recognition = new SpeechRecognition()
    this.recognition.continuous = false
    this.recognition.interimResults = true
    this.recognition.lang = 'en-US'
    this.recognition.maxAlternatives = 1
    
    this.recognition.onstart = () => {
      this.isRecording = true
      this.shouldBeListening = true
      this.updateUI(true)
      this.updateStatus('Listening... Speak now')
    }
    
    this.recognition.onresult = (event: any) => {
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
      
      // Update transcript display
      const transcriptEl = document.querySelector('[data-ai-voice-chat-target="transcript"]');
      if (transcriptEl) {
        transcriptEl.classList.remove('hidden')
        const statusEl = transcriptEl.querySelector('[data-ai-voice-chat-target="status"]')
        if (statusEl) {
          statusEl.textContent = finalTranscript || interimTranscript || 'Listening...'
        }
      }
      
      // Update input field
      const inputEl = document.querySelector('[data-ai-voice-chat-target="input"]') as HTMLTextAreaElement;
      if (inputEl) {
        inputEl.value = finalTranscript || interimTranscript
        inputEl.style.height = 'auto'
        const inputHeight = Math.min(inputEl.scrollHeight, 200)
        inputEl.style.height = `${inputHeight}px`
      }
      
      // Don't auto-submit - let user manually click send
      // This was previously auto-submitting when user paused while speaking
      console.log('[AiVoiceChat] Transcript ready:', finalTranscript)
    }
    
    this.recognition.onerror = (event: any) => {
      console.error('Speech recognition error:', event.error)
      
      // Stop on errors
      this.isRecording = false
      this.shouldBeListening = false
      this.updateUI(false)
      
      if (event.error === 'not-allowed') {
        this.updateStatus('Microphone access denied')
      } else if (event.error !== 'aborted') {
        this.updateStatus(`Error: ${event.error}`)
      }
    }
    
    this.recognition.onend = () => {
      this.isRecording = false
      this.shouldBeListening = false
      this.updateUI(false)
    }
  }
  
  toggle(): void {
    if (this.isProcessing) return
    
    if (this.isRecording) {
      this.stopListening()
    } else {
      this.startListening()
    }
  }
  
  private startListening(): void {
    if (!this.recognition) {
      this.initializeSpeechRecognition()
      if (!this.recognition) return
    }
    
    try {
      // Clear transcript display
      const transcriptEl = document.querySelector('[data-ai-voice-chat-target="transcript"]');
      if (transcriptEl) {
        transcriptEl.classList.add('hidden')
      }
      
      this.recognition.start()
    } catch (error: any) {
      console.error('Failed to start recognition:', error)
      if (error.message?.includes('already started')) {
        this.recognition.stop()
      }
    }
  }
  
  private stopListening(): void {
    this.shouldBeListening = false
    if (this.recognition && this.isRecording) {
      try {
        this.recognition.stop()
      } catch (e) {
        // Ignore
      }
    }
    this.isRecording = false
    this.updateUI(false)
  }
  
  submitVoiceMessage(event?: Event): void {
    event?.preventDefault()
    event?.stopPropagation()
    
    // Prevent double submission
    if (this.isProcessing) {
      console.warn('[AiVoiceChat] Already processing, ignoring submit')
      return
    }
    
    this.isProcessing = true
    this.updateStatus('Processing...')
    
    // Get the message from input
    const inputEl = document.querySelector('[data-ai-voice-chat-target="input"]') as HTMLTextAreaElement;
    const message = inputEl?.value?.trim();
    
    if (!message) {
      console.warn('[AiVoiceChat] No message to send')
      this.updateStatus('No message to send')
      this.isProcessing = false
      return
    }
    
    console.log('[AiVoiceChat] Submitting voice message:', message)
    
    // Get conversation ID from hidden field
    const convIdInput = document.querySelector('input[name="conversation_id"]') as HTMLInputElement;
    const conversationId = convIdInput?.value;
    
    console.log('[AiVoiceChat] Conversation ID:', conversationId)
    
    // Call the streaming API directly
    this.callStreamingAPI(conversationId, message)
    
    // Reset after a delay
    setTimeout(() => {
      this.isProcessing = false
      if (!this.isRecording) {
        this.updateStatus('Voice off')
      }
    }, 5000)
  }
  
  private async callStreamingAPI(conversationId: string | undefined, message: string): Promise<void> {
    // If no conversation ID, create a new one first
    let convId = conversationId;
    
    if (!convId) {
      try {
        const createResponse = await fetch('/api/v1/ai_chat/create_conversation', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
          },
          credentials: 'include'
        });
        const createData = await createResponse.json();
        convId = createData.conversation?.id;
        
        if (!convId) {
          this.updateStatus('Failed to create conversation');
          return;
        }
        
        // Reload to get new conversation
        window.location.href = `/ai_chat/${convId}`;
        return;
      } catch (e) {
        this.updateStatus('Error creating conversation');
        return;
      }
    }
    
    try {
      const response = await fetch('/api/v1/ai_chat/stream_message', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
        },
        body: JSON.stringify({
          conversation_id: convId,
          message: message
        }),
        credentials: 'include'
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to send message');
      }
      
      const data = await response.json();
      
      // Clear input
      const inputEl = document.querySelector('[data-ai-voice-chat-target="input"]') as HTMLTextAreaElement;
      if (inputEl) {
        inputEl.value = '';
      }
      
      // Manually append messages to chat container (since we're not using Turbo Stream)
      const chatContainer = document.getElementById("chat-messages");
      if (chatContainer && data) {
        // Remove empty state if exists
        const emptyState = chatContainer.querySelector('.flex.flex-col.items-center.justify-center');
        if (emptyState) {
          emptyState.remove();
        }
        
        // Append user message
        if (data.user_message) {
          const userHtml = this.buildMessageHtml('user', data.user_message.content, data.user_message.created_at);
          chatContainer.insertAdjacentHTML('afterbegin', userHtml);
        }
        
        // Append AI message
        if (data.ai_message) {
          const aiHtml = this.buildMessageHtml('assistant', data.ai_message.content, data.ai_message.created_at);
          chatContainer.insertAdjacentHTML('afterbegin', aiHtml);
        }
        
        // Scroll to top
        chatContainer.scrollTop = 0;
      }
      
      // Reset processing state immediately to allow new recordings
      this.isProcessing = false;
      this.updateStatus('Voice off');
      
    } catch (error: any) {
      console.error('Voice message error:', error);
      this.updateStatus(`Error: ${error.message}`);
    }
  }
  
  private buildMessageHtml(role: string, content: string, timestamp: string): string {
    const isUser = role === 'user';
    const time = timestamp
      ? new Date(timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      : new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    const userIcon = '👤';
    const aiIcon = '🤖';

    const userDivClass = 'w-10 h-10 rounded-xl flex items-center justify-center bg-gradient-to-br from-primary to-secondary';
    const aiDivClass = 'w-10 h-10 rounded-xl flex items-center justify-center bg-gradient-to-br from-green-500 to-emerald-500';
    const userBubbleClass = 'inline-block p-4 rounded-2xl bg-gradient-to-br from-primary to-secondary text-white';
    const aiBubbleClass = 'inline-block p-4 rounded-2xl bg-white dark:bg-gray-700 border border-purple-200 dark:border-gray-600 text-gray-900 dark:text-white';
    const alignClass = isUser ? 'text-right' : 'text-left';

    return `
      <div class="message ${role} mb-4 flex ${isUser ? 'justify-end' : 'justify-start'}">
        <div class="flex ${isUser ? 'flex-row-reverse' : 'flex-row'} items-start gap-3 max-w-3xl">
          <div class="flex-shrink-0">
            <div class="${isUser ? userDivClass : aiDivClass}">
              ${isUser ? userIcon : aiIcon}
            </div>
          </div>
          <div class="${alignClass}">
            <div class="${isUser ? userBubbleClass : aiBubbleClass} shadow-sm">
              <p class="text-sm whitespace-pre-wrap">${content}</p>
            </div>
            <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">${time}</p>
          </div>
        </div>
      </div>
    `;
  }
  
  private updateUI(listening: boolean): void {
    const buttonEl = document.querySelector('[data-ai-voice-chat-target="button"]') as HTMLButtonElement;
    const indicatorEl = document.querySelector('[data-ai-voice-chat-target="indicator"]');
    
    if (buttonEl) {
      if (listening) {
        buttonEl.classList.add('listening', 'animate-pulse')
        buttonEl.classList.remove('bg-white/80', 'border', 'border-border/50')
        buttonEl.classList.add('bg-red-500', 'text-white')
      } else {
        buttonEl.classList.remove('listening', 'animate-pulse', 'bg-red-500', 'text-white')
        buttonEl.classList.add('bg-white/80', 'border', 'border-border/50')
      }
    }
    
    if (indicatorEl) {
      if (listening) {
        indicatorEl.classList.remove('hidden')
      } else {
        indicatorEl.classList.add('hidden')
      }
    }
  }
  
  private updateStatus(text: string): void {
    const statusEl = document.querySelector('[data-ai-voice-chat-target="status"]');
    if (statusEl) {
      statusEl.textContent = text;
    }
  }
}
