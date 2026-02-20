import { Controller } from "@hotwired/stimulus"

// AI Voice Chat Controller - Uses browser's webkitSpeechRecognition
export default class AiVoiceChatController extends Controller {
  static targets = ["button", "indicator", "status", "transcript"]
  
  declare readonly buttonTarget: HTMLButtonElement
  declare readonly indicatorTarget: HTMLElement
  declare readonly statusTarget: HTMLElement
  declare readonly transcriptTarget: HTMLElement
  
  private recognition: any = null
  private isRecording: boolean = false
  private isProcessing: boolean = false
  
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
      
      // If we have final transcript, submit
      if (finalTranscript) {
        this.submitVoiceMessage()
      }
    }
    
    this.recognition.onerror = (event: any) => {
      console.error('Speech recognition error:', event.error)
      this.isRecording = false
      this.updateUI(false)
      
      if (event.error === 'not-allowed') {
        this.updateStatus('Microphone access denied')
      } else if (event.error !== 'aborted') {
        this.updateStatus(`Error: ${event.error}`)
      }
    }
    
    this.recognition.onend = () => {
      this.isRecording = false
      this.updateUI(false)
      
      if (!this.isProcessing) {
        this.updateStatus('Voice off')
      }
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
  
  submitVoiceMessage(): void {
    this.isProcessing = true
    this.updateStatus('Processing...')
    
    // Get the message from input
    const inputEl = document.querySelector('[data-ai-voice-chat-target="input"]') as HTMLTextAreaElement;
    const message = inputEl?.value?.trim();
    
    if (!message) {
      this.updateStatus('No message to send')
      this.isProcessing = false
      return
    }
    
    // Get conversation ID from hidden field
    const convIdInput = document.querySelector('input[name="conversation_id"]') as HTMLInputElement;
    const conversationId = convIdInput?.value;
    
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
            'Accept': 'application/json'
          }
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
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          conversation_id: convId,
          message: message
        })
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to send message');
      }
      
      // Clear input
      const inputEl = document.querySelector('[data-ai-voice-chat-target="input"]') as HTMLTextAreaElement;
      if (inputEl) {
        inputEl.value = '';
      }
      
      this.updateStatus('Processing complete');
      
    } catch (error: any) {
      console.error('Voice message error:', error);
      this.updateStatus(`Error: ${error.message}`);
    }
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
