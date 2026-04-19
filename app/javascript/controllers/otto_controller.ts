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
}