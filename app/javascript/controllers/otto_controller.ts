import { Controller } from "@hotwired/stimulus";
import { showToast } from "../toast";

export default class OttoController extends Controller {
  static targets = ["panel", "messages", "input"];

  declare readonly panelTarget: HTMLElement;
  declare readonly messagesTarget: HTMLElement;
  declare readonly inputTarget: HTMLTextAreaElement;

  private csrfToken: string | null = null;
  private isOpen = false;
  private isRecording = false;
  private isTTSEnabled = false;
  private selectedLanguage = 'en';
  private mediaRecorder: MediaRecorder | null = null;
  private audioChunks: Blob[] = [];
  private currentConversationId: string | null = null;
  private speechRecognition: any = null;

  connect() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    this.csrfToken = meta instanceof HTMLMetaElement ? meta.content : null;
    // Load TTS preference from localStorage
    this.isTTSEnabled = localStorage.getItem('otto_tts_enabled') === 'true';
    // Load saved language or default to en
    this.selectedLanguage = localStorage.getItem('otto_language') || 'en';
    // Update language selector to match saved preference
    const langSelect = document.getElementById('otto-language-select') as HTMLSelectElement;
    if (langSelect) langSelect.value = this.selectedLanguage;
    this.updateTTSIcons();
    this.updateVoiceModeIcons();

    // Listen for conversation events from sidebar
    document.addEventListener('otto:load-conversation', this.handleLoadConversation);
    document.addEventListener('otto:new-conversation', this.handleNewConversation);
    document.addEventListener('otto:conversation-deleted', this.handleConversationDeleted);
  }

  disconnect() {
    document.removeEventListener('otto:load-conversation', this.handleLoadConversation);
    document.removeEventListener('otto:new-conversation', this.handleNewConversation);
    document.removeEventListener('otto:conversation-deleted', this.handleConversationDeleted);
  }

  private handleLoadConversation = (event: Event) => {
    const customEvent = event as CustomEvent;
    const { id, title, messages } = customEvent.detail;
    this.currentConversationId = id?.toString() || null;
    this.loadMessages(messages);
    this.updateHeaderTitle(title);
  }

  private handleNewConversation = () => {
    this.currentConversationId = null;
    this.messagesTarget.innerHTML = '';
    this.addWelcomeMessage();
    this.updateHeaderTitle('New Chat');
  }

  private handleConversationDeleted = () => {
    this.currentConversationId = null;
    this.messagesTarget.innerHTML = '';
    this.addWelcomeMessage();
    this.updateHeaderTitle('New Chat');
  }

  private updateHeaderTitle(title: string) {
    const titleEl = document.getElementById('otto-header-title');
    if (titleEl) {
      const truncated = title.length > 30 ? `${title.substring(0, 30)}...` : title;
      titleEl.textContent = truncated;
    }
  }

  toggle() {
    this.isOpen = !this.isOpen;
    const widget = document.getElementById('otto-widget');
    if (widget) {
      widget.classList.toggle('otto-widget-open', this.isOpen);
      widget.classList.toggle('otto-widget-closed', !this.isOpen);
    }
    if (this.isOpen) {
      this.loadHistory();
      setTimeout(() => this.inputTarget?.focus(), 100);
    }
  }

  toggleSidebar() {
    const sidebar = document.getElementById('otto-sidebar');
    if (sidebar) {
      // Dispatch event to open sidebar
      const customEvent = new CustomEvent('otto:open-sidebar');
      document.dispatchEvent(customEvent);
    }
  }

  toggleTTS(): void {
    this.isTTSEnabled = !this.isTTSEnabled;
    localStorage.setItem('otto_tts_enabled', this.isTTSEnabled ? 'true' : 'false');
    this.updateTTSIcons();
  }

  toggleVoiceMode(): void {
    const currentMode = this.voiceMode;
    const newMode = currentMode === 'auto' ? 'manual' : 'auto';
    localStorage.setItem('otto_voice_mode', newMode);
    this.updateVoiceModeIcons();
    showToast(`Voice mode: ${newMode === 'auto' ? 'Auto (sends on silence)' : 'Manual (press again to send)'}`, 'info');
  }

  private updateVoiceModeIcons(): void {
    const autoIcon = document.getElementById('otto-voice-mode-auto-icon');
    const manualIcon = document.getElementById('otto-voice-mode-manual-icon');
    if (autoIcon && manualIcon) {
      const isAuto = this.voiceMode === 'auto';
      autoIcon.classList.toggle('hidden', !isAuto);
      manualIcon.classList.toggle('hidden', isAuto);
    }
  }

  private updateTTSIcons(): void {
    const onIcon = document.getElementById('otto-tts-on-icon');
    const offIcon = document.getElementById('otto-tts-off-icon');
    if (onIcon && offIcon) {
      onIcon.classList.toggle('hidden', !this.isTTSEnabled);
      offIcon.classList.toggle('hidden', this.isTTSEnabled);
    }
  }

  changeLanguage(): void {
    const select = document.getElementById('otto-language-select') as HTMLSelectElement;
    if (select) {
      this.selectedLanguage = select.value;
      localStorage.setItem('otto_language', select.value);
    }
  }

  private loadHistory() {
    // If we have a conversation ID, load it; otherwise check for messages
    if (this.currentConversationId) {
      this.loadConversationById(this.currentConversationId);
      return;
    }
    
    // Check if there are any messages already displayed
    const userMessages = this.messagesTarget.querySelectorAll('.otto-msg.user').length;
    if (userMessages > 0) return;

    // Try to load most recent conversation
    this.loadMostRecentConversation();
  }

  private async loadMostRecentConversation() {
    try {
      const response = await fetch('/assistant', {
        headers: {
          'X-CSRF-Token': this.csrfToken || '',
          'Accept': 'application/json'
        }
      });

      if (!response.ok) return;

      const data = await response.json();
      if (data.conversations && data.conversations.length > 0) {
        const recent = data.conversations[0];
        this.currentConversationId = recent.id.toString();
        await this.loadConversationById(recent.id.toString());
      } else {
        this.addWelcomeMessage();
      }
    } catch (error) {
      console.error('[Otto] Error loading recent conversation:', error);
      this.addWelcomeMessage();
    }
  }

  private async loadConversationById(id: string) {
    try {
      const response = await fetch(`/assistant/${id}`, {
        headers: { 
          'X-CSRF-Token': this.csrfToken || '',
          'Accept': 'application/json'
        }
      });
      
      if (!response.ok) {
        this.addWelcomeMessage();
        return;
      }
      
      const data = await response.json();
      if (data.messages && data.messages.length > 0) {
        this.messagesTarget.innerHTML = '';
        data.messages.forEach((msg: {role: string, content: string}) => {
          if (msg.role === 'user' || msg.role === 'assistant') {
            this.appendMessage(msg.role as 'user' | 'assistant', msg.content);
          }
        });
        this.updateHeaderTitle(data.title);
      } else {
        this.addWelcomeMessage();
      }
    } catch (error) {
      console.error('[Otto] Error loading conversation:', error);
      this.addWelcomeMessage();
    }
  }

  private loadMessages(messages: Array<{role: string, content: string}>) {
    this.messagesTarget.innerHTML = '';
    if (messages && messages.length > 0) {
      messages.forEach((msg) => {
        if (msg.role === 'user' || msg.role === 'assistant') {
          this.appendMessage(msg.role as 'user' | 'assistant', msg.content);
        }
      });
    } else {
      this.addWelcomeMessage();
    }
  }

  private addWelcomeMessage() {
    this.messagesTarget.innerHTML = '';
    const welcome = "👋 Hey! I'm Otto-Pilot, your AI assistant. I can help you " +
      "write content, brainstorm ideas, answer questions, or anything else you " +
      "need. What can I do for you today?";
    this.appendMessage('assistant', welcome);
  }

  handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      this.send();
    }
    const target = event.target as HTMLTextAreaElement;
    target.style.height = 'auto';
    target.style.height = `${Math.min(target.scrollHeight, 100)}px`;
  }

  private escapeHtml(text: string): string {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/\n/g, '<br>');
  }

  private appendMessage(role: 'user' | 'assistant', content: string) {
    const div = document.createElement('div');
    const bubbleClass = role === 'user'
      ? 'rounded-br-md bg-gradient-to-r from-primary to-purple-500 text-white'
      : 'rounded-bl-md bg-white text-gray-800';
    div.className = `otto-msg ${role} flex ${role === 'user' ? 'justify-end' : 'justify-start'}`;
    div.innerHTML = `<div class="otto-bubble max-w-[80%] px-4 py-3 rounded-2xl ${bubbleClass} text-sm shadow-sm">${this.escapeHtml(content)}</div>`;
    this.messagesTarget.appendChild(div);
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
  }

  private appendImageMessage(imageUrl: string, caption?: string) {
    const div = document.createElement('div');
    div.className = 'otto-msg assistant flex justify-start';
    div.innerHTML = `
      <div class="max-w-[85%] px-4 py-3 rounded-2xl rounded-bl-md bg-white shadow-sm">
        <img src="${imageUrl}" alt="Generated image" class="rounded-lg max-w-full max-h-64 object-cover mb-2" loading="lazy" />
        ${caption ? `<p class="text-sm text-gray-700">${this.escapeHtml(caption)}</p>` : ''}
      </div>
    `;
    this.messagesTarget.appendChild(div);
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
  }

  private appendTaskResult(task: any) {
    if (task.type === 'image' && task.draft_id) {
      this.startPollingForImage(task.draft_id);
    }
  }

  private startPollingForImage(draftId: number) {
    const container = document.createElement('div');
    container.id = `otto-poll-${draftId}`;
    container.innerHTML = `
      <div class="otto-msg assistant flex justify-start">
        <div class="max-w-[80%] px-4 py-3 rounded-2xl rounded-bl-md bg-white shadow-sm">
          <div class="flex items-center gap-2 text-gray-500 text-sm">
            <div class="otto-dot"></div>
            <div class="otto-dot"></div>
            <div class="otto-dot"></div>
            <span>Generating image...</span>
          </div>
        </div>
      </div>
    `;
    this.messagesTarget.appendChild(container);
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;

    let attempts = 0;
    const maxAttempts = 60;

    const poll = () => {
      attempts++;

      fetch(`/api/v1/otto/draft_status?id=${draftId}`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken || ''
        }
      })
        .then(response => response.json())
        .then(data => {
          if (data.media_url) {
            container.remove();
            this.appendImageMessage(data.media_url, data.content);
            showToast('Image ready!', 'success');
          } else if (attempts < maxAttempts && this.isOpen) {
            setTimeout(poll, 5000);
          } else if (attempts >= maxAttempts) {
            container.remove();
            this.appendMessage('assistant', 'Image generation is taking longer than expected. Check your drafts for the result.');
          }
        })
        .catch(() => {
          if (attempts < maxAttempts && this.isOpen) {
            setTimeout(poll, 5000);
          }
        });
    };

    setTimeout(poll, 3000);
  }

  private showTyping() {
    const div = document.createElement('div');
    div.className = 'otto-msg assistant flex justify-start';
    div.id = 'otto-typing-indicator';
    div.innerHTML = `<div class="otto-bubble max-w-[80%] px-4 py-3 rounded-2xl rounded-bl-md bg-white shadow-sm">
            <div class="otto-dot"></div>
            <div class="otto-dot"></div>
            <div class="otto-dot"></div>
        </div>`;
    this.messagesTarget.appendChild(div);
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
  }

  private hideTyping() {
    const indicator = document.getElementById('otto-typing-indicator');
    if (indicator) indicator.remove();
  }

  send() {
    const message = this.inputTarget.value.trim();
    if (!message) return;

    this.inputTarget.value = '';
    this.inputTarget.style.height = 'auto';
    const sendBtn = document.getElementById('otto-send') as HTMLButtonElement | null;
    if (sendBtn) {
      sendBtn.disabled = true;
      sendBtn.style.opacity = '0.5';
      sendBtn.style.cursor = 'not-allowed';
    }

    this.appendMessage('user', message);
    this.showTyping();

    // Include conversation_id and language if available
    const body: { message: string; conversation_id?: string; language?: string } = { message };
    if (this.currentConversationId) {
      body.conversation_id = this.currentConversationId;
    }
    body.language = this.selectedLanguage;

    fetch('/api/v1/otto/chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken || ''
      },
      body: JSON.stringify(body)
    })
      .then(response => {
        console.log('[Otto] Response status:', response.status);
        return response.json();
      })
      .then(data => {
        console.log('[Otto] Response data:', data);
        this.hideTyping();
        if (data.reply !== undefined && data.reply !== null) {
          this.appendMessage('assistant', data.reply);

          if (data.task) {
            this.appendTaskResult(data.task);
          }

          // Update conversation ID if returned
          if (data.conversation_id) {
            this.currentConversationId = data.conversation_id.toString();
          }

          // Play TTS audio if available and enabled (checked via localStorage)
          if (data.audio_url && localStorage.getItem('otto_tts_enabled') === 'true') {
            this.playAudio(data.audio_url);
          }
        } else if (data.error) {
          this.appendMessage('assistant', data.error);
        } else {
          this.appendMessage('assistant', 'Something went wrong. Please try again.');
        }
      })
      .catch(() => {
        this.hideTyping();
        this.appendMessage('assistant', 'Network error. Please check your connection.');
      })
      .finally(() => {
        if (sendBtn) {
          sendBtn.disabled = false;
          sendBtn.style.opacity = '1';
          sendBtn.style.cursor = 'pointer';
        }
      });
  }

  clear() {
    // Use a simple approach - start new conversation
    this.messagesTarget.innerHTML = '';
    this.currentConversationId = null;
    this.addWelcomeMessage();
    this.updateHeaderTitle('New Chat');

    // Notify sidebar to refresh
    document.dispatchEvent(new CustomEvent('otto:conversation-cleared'));
  }

  toggleMic() {
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      showToast('Speech recognition not supported in this browser', 'error');
      return;
    }

    if (this.isRecording) {
      // User pressed mic to stop - stop and send (both modes)
      this.stopRecording(true);
    } else {
      // User pressed mic to start recording
      this.startRecording();
    }
  }

  private get voiceMode(): 'auto' | 'manual' {
    const mode = localStorage.getItem('otto_voice_mode');
    return (mode === 'manual') ? 'manual' : 'auto';
  }

  private startRecording() {
    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    this.speechRecognition = new SpeechRecognition();
    
    // Auto mode: detect end of speech and send automatically
    // Manual mode: keep listening until user presses mic again
    this.speechRecognition.continuous = this.voiceMode === 'manual';
    this.speechRecognition.interimResults = true;
    this.speechRecognition.maxAlternatives = 1;
    // Set the language based on user's selection
    this.speechRecognition.lang = this.selectedLanguage;


    this.speechRecognition.onresult = (event: any) => {
      // Get the final transcript
      const lastResultIndex = event.results.length - 1;
      const result = event.results[lastResultIndex];
      const transcript = result[0].transcript;
      this.inputTarget.value = transcript;
    };

    this.speechRecognition.onerror = (event: any) => {
      // Only stop UI state if it's a fatal error, not for silence/no-match
      if (event.error === 'no-speech' || event.error === 'aborted') {
        // These are expected - restart in manual mode
        if (this.voiceMode === 'manual' && this.isRecording) {
          this.restartRecording();
        } else {
          this.isRecording = false;
          this.updateMicUI(false);
        }
      } else {
        // Fatal error - stop everything
        this.isRecording = false;
        this.updateMicUI(false);
      }
    };

    this.speechRecognition.onend = () => {
      if (this.isRecording) {
        // In manual mode, restart recognition to keep listening
        // In auto mode, this is expected and we'll stop below
        if (this.voiceMode === 'manual') {
          this.restartRecording();
        } else {
          // Auto mode: speech ended, stop and send
          this.isRecording = false;
          this.updateMicUI(false);
          if (this.inputTarget.value.trim()) {
            this.send();
          }
        }
      }
    };

    this.speechRecognition.start();
    this.isRecording = true;
    this.updateMicUI(true);
  }

  private restartRecording() {
    // Restart speech recognition for manual mode (keep-alive)
    if (!this.isRecording) return;
    
    const SpeechRecognition = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    const previousTranscript = this.inputTarget.value;
    
    this.speechRecognition = new SpeechRecognition();
    this.speechRecognition.continuous = true;
    this.speechRecognition.interimResults = true;
    this.speechRecognition.maxAlternatives = 1;


    this.speechRecognition.onresult = (event: any) => {
      const lastResultIndex = event.results.length - 1;
      const result = event.results[lastResultIndex];
      const transcript = result[0].transcript;
      this.inputTarget.value = transcript;
    };

    this.speechRecognition.onerror = (event: any) => {
      if (event.error === 'no-speech' || event.error === 'aborted') {
        if (this.voiceMode === 'manual' && this.isRecording) {
          this.restartRecording();
        } else {
          this.isRecording = false;
          this.updateMicUI(false);
        }
      } else {
        this.isRecording = false;
        this.updateMicUI(false);
      }
    };

    this.speechRecognition.onend = () => {
      if (this.isRecording && this.voiceMode === 'manual') {
        this.restartRecording();
      }
    };

    this.speechRecognition.start();
    // UI stays in recording state
  }

  private updateMicUI(recording: boolean) {
    const micBtn = document.getElementById('otto-mic-btn');
    const statusDiv = document.getElementById('otto-voice-status');
    const statusText = document.getElementById('otto-status-text');

    if (micBtn) {
      micBtn.classList.toggle('recording', recording);
    }
    if (statusDiv) {
      statusDiv.classList.toggle('hidden', !recording);
      statusDiv.classList.toggle('listening', recording);
      statusDiv.classList.toggle('processing', !recording);
    }
    if (statusText) {
      statusText.textContent = this.voiceMode === 'manual' ? 'Tap mic to send...' : 'Listening...';
    }
  }

  private stopRecording(send: boolean) {
    const wasRecording = this.isRecording;
    
    if (this.speechRecognition) {
      this.speechRecognition.stop();
      this.speechRecognition = null;
    }
    this.isRecording = false;
    this.updateMicUI(false);

    // Only send if user pressed stop AND there's text AND in manual mode OR auto mode with silence detection
    if (send && wasRecording && this.inputTarget.value.trim()) {
      this.send();
    }
  }

  private playAudio(url: string) {
    const audio = new Audio(url);
    audio.play().catch(() => {});
  }
}
