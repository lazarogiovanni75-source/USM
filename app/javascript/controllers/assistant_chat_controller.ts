import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static targets = ["panel", "messages", "input", "onboardingBar"]

  declare readonly panelTarget: HTMLElement
  declare readonly messagesTarget: HTMLElement
  declare readonly inputTarget: HTMLInputElement
  declare readonly onboardingBarTarget: HTMLElement | undefined

  private isOpen = false

  connect(): void {
    console.log("AssistantChat controller connected")
  }

  toggle(): void {
    this.isOpen = !this.isOpen
    const panel = document.getElementById('assistant-panel')
    const bubbleIcon = document.getElementById('bubble-icon')
    
    if (panel) {
      panel.style.display = this.isOpen ? 'flex' : 'none'
    }
    
    if (bubbleIcon) {
      bubbleIcon.textContent = this.isOpen ? '✕' : '💬'
    }
    
    if (this.isOpen && this.inputTarget) {
      this.inputTarget.focus()
    }
  }

  closeOnNavigate(): void {
    this.isOpen = false
    const panel = document.getElementById('assistant-panel')
    if (panel) {
      panel.style.display = 'none'
    }
    const bubbleIcon = document.getElementById('bubble-icon')
    if (bubbleIcon) {
      bubbleIcon.textContent = '💬'
    }
  }

  handleKeydown(event: KeyboardEvent): void {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage()
    }
  }

  async sendMessage(): Promise<void> {
    const message = this.inputTarget?.value.trim()
    if (!message) return

    // Show user message
    this.appendMessage(message, 'user')
    this.inputTarget.value = ''

    // Show typing indicator
    const typing = this.appendTyping()

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      
      const response = await fetch('/assistants/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken || ''
        },
        body: JSON.stringify({
          message: message,
          current_page: window.location.pathname
        })
      })

      const data = await response.json()
      typing.remove()

      if (data.reply) {
        this.appendMessage(data.reply, 'assistant')

        // Update progress bar if onboarding changed
        if (data.onboarding_progress) {
          const fill = document.getElementById('progress-fill')
          if (fill) {
            fill.style.width = `${data.onboarding_progress.percentage}%`
          }
          
          // Update badge
          const badge = document.getElementById('onboarding-badge')
          if (badge) {
            badge.textContent = `${data.onboarding_progress.completed}/${data.onboarding_progress.total}`
          }
        }
      }
    } catch (err) {
      typing.remove()
      this.appendMessage('Sorry, something went wrong. Please try again.', 'assistant')
    }
  }

  private appendMessage(text: string, role: 'user' | 'assistant'): HTMLElement {
    const div = document.createElement('div')
    div.className = role === 'user' ? 'user-msg' : 'assistant-msg'
    div.textContent = text
    this.messagesTarget.appendChild(div)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    return div
  }

  private appendTyping(): HTMLElement {
    const div = document.createElement('div')
    div.className = 'typing-indicator'
    div.textContent = '•••'
    this.messagesTarget.appendChild(div)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    return div
  }
}
