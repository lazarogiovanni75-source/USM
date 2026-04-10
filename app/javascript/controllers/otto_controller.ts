import { Controller } from "@hotwired/stimulus";
import { showToast } from "../toast";

export default class OttoController extends Controller {
  static targets = ["panel", "messages", "input"];

  declare readonly panelTarget: HTMLElement;
  declare readonly messagesTarget: HTMLElement;
  declare readonly inputTarget: HTMLTextAreaElement;

  private csrfToken: string | null = null;
  private isOpen = false;

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
      setTimeout(() => this.inputTarget?.focus(), 100);
    }
  }

  handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      this.send();
    }
    const target = event.target as HTMLTextAreaElement;
    target.style.height = 'auto';
    target.style.height = `${Math.min(target.scrollHeight, 100)  }px`;
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
      .then(response => response.json())
      .then(data => {
        this.hideTyping();
        if (data.reply) {
          this.appendMessage('assistant', data.reply);
        } else {
          this.appendMessage('assistant', data.error || 'Something went wrong. Please try again.');
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
