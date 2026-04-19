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
  private mediaRecorder: MediaRecorder | null = null;
  private audioChunks: Blob[] = [];

  connect() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    this.csrfToken = meta instanceof HTMLMetaElement ? meta.content : null;
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

private loadHistory() {
  const userMessages = this.messagesTarget.querySelectorAll('.otto-msg.user').length;
  if (userMessages > 0) return;

  fetch('/api/v1/otto/history', {
    headers: { 'X-CSRF-Token': this.csrfToken || '' }
  })
    .then(r => r.json())
    .then(data => {
      if (data.messages && data.messages.length > 0) {
        this.messagesTarget.innerHTML = '';
        data.messages.forEach((msg: {role: string, content: string}) => {
          this.appendMessage(msg.role as 'user' | 'assistant', msg.content);
        });
      }
    })
    .catch(() => {});
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
      .replace(/>/g, '&gt')
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
    // Create a polling container that will be updated via Turbo Stream
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

    // Poll using fetch - this is for Otto widget's image polling which is a background task
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
            // Remove polling indicator
            container.remove();
            // Show the image
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

    fetch('/api/v1/otto/chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken || ''
      },
      body: JSON.stringify({ message })
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
        } else if (data.error) {
          this.appendMessage('assistant', data.error);
        } else {
          this.appendMessage('assistant', 'Something went wrong. Please try again.');
        }
      })
      .catch(() => {
        this.hideTyping();
        this.appendMessage('assistant', 'Connection error. Please check your internet and try again.');
      })
      .finally(() => {
        if (sendBtn) {
          sendBtn.disabled = false;
          sendBtn.style.opacity = '1';
          sendBtn.style.cursor = 'pointer';
        }
        this.inputTarget.focus();
      });
  }

  clear() {
    showToast('Conversation cleared!', 'success');

    fetch('/api/v1/otto/clear', {
      method: 'POST',
      headers: { 'X-CSRF-Token': this.csrfToken || '' }
    });

    this.messagesTarget.innerHTML = `
            <div class="otto-msg assistant flex justify-start">
                <div class="max-w-[80%] px-4 py-3 rounded-2xl rounded-bl-md bg-white text-gray-800 text-sm shadow-sm">
                    👋 Conversation cleared! How can I help you?
                </div>
            </div>
        `;
  }

  async toggleMic() {
    if (this.isRecording) {
      this.stopRecording();
    } else {
      await this.startRecording();
    }
  }

  async startRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      // Use mimeType for better compatibility
      const mimeType = MediaRecorder.isTypeSupported('audio/webm;codecs=opus') 
        ? 'audio/webm;codecs=opus' 
        : 'audio/webm';
      this.mediaRecorder = new MediaRecorder(stream, { mimeType });
      this.audioChunks = [];
      this.isRecording = true;

      this.updateMicButton(true);
      this.updateVoiceStatus('listening');

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) {
          this.audioChunks.push(e.data);
        }
      };

      this.mediaRecorder.onstop = () => {
        this.handleRecordingComplete();
        stream.getTracks().forEach(track => track.stop());
      };

      // Request data every 100ms for smoother recording
      this.mediaRecorder.start(100);
    } catch (error) {
      console.error('Microphone error:', error);
      showToast('Could not access microphone. Please check permissions.', 'error');
      this.isRecording = false;
      this.updateMicButton(false);
      this.updateVoiceStatus('idle');
    }
  }

  stopRecording() {
    if (this.mediaRecorder && this.isRecording) {
      this.isRecording = false;
      this.mediaRecorder.stop();
      this.updateMicButton(false);
      this.updateVoiceStatus('processing');
    }
  }

  async handleRecordingComplete() {
    if (this.audioChunks.length === 0) {
      this.updateVoiceStatus('idle');
      return;
    }

    const audioBlob = new Blob(this.audioChunks, { type: 'audio/webm' });
    const formData = new FormData();
    formData.append('audio', audioBlob, 'voice.webm');

    try {
      const response = await fetch('/api/v1/otto/transcribe', {
        method: 'POST',
        headers: { 'X-CSRF-Token': this.csrfToken || '' },
        body: formData
      });

      const data = await response.json();

      if (data.text) {
        this.inputTarget.value = data.text;
        this.inputTarget.dispatchEvent(new Event('input'));
        this.send();
      } else {
        showToast(data.error || 'Could not understand audio. Please try again.', 'error');
      }
    } catch (error) {
      console.error('Transcription error:', error);
      showToast('Transcription failed. Please try again.', 'error');
    } finally {
      this.updateVoiceStatus('idle');
    }
  }

  private updateMicButton(recording: boolean) {
    const micBtn = document.getElementById('otto-mic-btn');
    if (micBtn) {
      if (recording) {
        micBtn.classList.add('recording');
        micBtn.innerHTML = `
          <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 10a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1h-4a1 1 0 01-1-1v-4z"/>
          </svg>
        `;
      } else {
        micBtn.classList.remove('recording');
        micBtn.innerHTML = `
          <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4
                 m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
          </svg>
        `;
      }
    }
  }

  private updateVoiceStatus(state: 'idle' | 'listening' | 'processing') {
    const statusEl = document.getElementById('otto-voice-status');
    const statusText = document.getElementById('otto-status-text');

    if (!statusEl || !statusText) return;

    statusEl.classList.remove('hidden', 'listening', 'processing');

    if (state === 'idle') {
      statusEl.classList.add('hidden');
    } else if (state === 'listening') {
      statusEl.classList.add('listening');
      statusText.textContent = 'Listening...';
    } else if (state === 'processing') {
      statusEl.classList.add('processing');
      statusText.textContent = 'Processing...';
    }
  }
}
