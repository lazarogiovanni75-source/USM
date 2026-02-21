import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

const USER_AVATAR = (
  "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'>" +
  "<path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' " +
  "d='M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z'>" +
  "</path></svg>"
)

const BOT_AVATAR = (
  "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'>" +
  "<path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' " +
  "d='M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3" +
  "m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 " +
  "3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754" +
  "-.988-2.386l-.548-.547z'></path></svg>"
)

const SPINNER = (
  "<svg class='w-5 h-5 animate-spin' fill='none' stroke='currentColor' viewBox='0 0 24 24'>" +
  "<circle class='opacity-25' cx='12' cy='12' r='10' stroke='currentColor' stroke-width='4'></circle>" +
  "<path class='opacity-75' fill='currentColor' d='M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z'></path></svg>"
)

const SEND_ICON = (
  "<svg class='w-5 h-5' fill='none' stroke='currentColor' viewBox='0 0 24 24'>" +
  "<path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' " +
  "d='M12 19l9 2-9-18-9 18 9-2zm0 0v-8'></path></svg>"
)

const QUICK_PROMPT_CLASS = (
  "quick-prompt px-4 py-2 bg-white/80 backdrop-blur-sm " +
  "border border-border/50 rounded-full text-sm text-primary " +
  "hover:bg-primary hover:text-white transition-all"
)

const CLOSE_ICON = (
  "<svg class='w-5 h-5' fill='none' stroke='currentColor' viewBox='0 0 24 24'>" +
  "<path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' " +
  "d='M6 18L18 6M6 6l12 12'></path></svg>"
)

const WARNING_ICON = (
  "<svg class='w-6 h-6 text-amber-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'>" +
  "<path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' " +
  "d='M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z'></path></svg>"
)

const STOP_ICON = (
  "<svg class='w-5 h-5' fill='none' stroke='currentColor' viewBox='0 0 24 24'>" +
  "<path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' " +
  "d='M21 12a9 9 0 11-18 0 9 9 0 0118 0z'></path>" +
  "<path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' " +
  "d='M9 10a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1h-4a1 1 0 01-1-1v-4z'></path></svg>"
)

// stimulus-validator: disable-next-line
export default class extends Controller<HTMLElement> {
  // stimulus-validator: disable-next-line
  static values = {
    conversationId: String
  }

  // stimulus-validator: disable-next-line
  static targets = ["form", "input", "messagesContainer", "sendBtn"]

  declare readonly conversationIdValue: string
  declare readonly formTarget: HTMLFormElement
  declare readonly inputTarget: HTMLTextAreaElement
  declare readonly messagesContainerTarget: HTMLElement
  declare readonly sendBtnTarget: HTMLButtonElement

  private cableSubscription: any = null
  private isGenerating: boolean = false
  private currentAssistantMessage: HTMLElement | null = null
  private autopilotConversationId: string | null = null
  private isRecording: boolean = false
  private abortController: AbortController | null = null

  connect(): void {
    console.log("AI Chat controller connected")
    this.subscribeToCable()
  }

  disconnect(): void {
    this.cableSubscription?.unsubscribe()
  }

  private subscribeToCable(): void {
    const conversationId = this.conversationIdValue
    if (!conversationId) {
      console.log("No conversation ID, skipping ActionCable subscription")
      return
    }

    const streamName = `ai_chat_${conversationId}`
    // Use proper ActionCable subscription format with channel class
    this.cableSubscription = consumer.subscriptions.create(
      { channel: "AiChatChannel", conversation_id: conversationId },
      {
        received: (data: any) => {
          this.handleCableMessage(data)
        }
      }
    )
    console.log("Subscribed to ActionCable:", streamName)
  }

  private handleCableMessage(data: any): void {
    switch (data.type) {
      case 'content_delta':
        this.appendContentDelta(data.delta)
        break
      case 'completion':
        this.handleCompletion()
        break
      case 'error':
        this.handleError(data.error)
        break
      case 'typing':
        if (data.status) this.showTypingIndicator()
        else this.hideTypingIndicator()
        break
      case 'chunk':
        this.appendChunk(data.chunk, data.message_id)
        break
      case 'complete':
        this.handleComplete(data)
        break
      case 'tool_call':
        this.handleToolCall(data)
        break
      case 'tool_result':
        this.handleToolResult(data)
        break
      case 'confirmation_required':
        this.handleConfirmationRequired(data)
        break
      case 'tool_confirmed':
        this.handleToolConfirmed(data)
        break
      case 'tool_rejected':
        this.handleToolRejected(data)
        break
    }
  }

  private appendContentDelta(delta: string): void {
    let messageEl = this.currentAssistantMessage
    if (!messageEl) {
      this.hideTypingIndicator()
      messageEl = this.createAssistantMessageElement()
      this.messagesContainerTarget.appendChild(messageEl)
      this.currentAssistantMessage = messageEl
    }
    const contentEl = messageEl.querySelector('.message-content')
    if (contentEl) {
      contentEl.innerHTML += this.escapeHtml(delta)
      this.scrollToBottom()
    }
  }

  private handleCompletion(): void {
    this.isGenerating = false
    this.hideTypingIndicator()
    this.showStopButton(false)
    this.setLoading(false)
    this.inputTarget.disabled = false
    this.currentAssistantMessage = null
    this.abortController = null
  }

  private handleToolCall(data: any): void {
    // Show tool call indicator
    const toolDiv = document.createElement('div')
    toolDiv.id = 'tool-call-indicator'
    toolDiv.className = 'mb-2 p-3 bg-blue-50 border border-blue-200 rounded-lg'
    toolDiv.innerHTML = `<p class="text-xs text-blue-600">🔧 Executing: ${this.escapeHtml(data.tool_name)}...</p>`
    
    const msgEl = this.currentAssistantMessage
    if (msgEl) {
      msgEl.querySelector('.message-content')?.appendChild(toolDiv)
    }
    this.scrollToBottom()
  }

  private handleToolResult(data: any): void {
    // Update tool call indicator with result
    const toolDiv = document.getElementById('tool-call-indicator')
    if (toolDiv) {
      const result = data.result
      if (result.success !== false) {
        toolDiv.className = 'mb-2 p-3 bg-green-50 border border-green-200 rounded-lg'
        toolDiv.innerHTML = `<p class="text-xs text-green-600">✅ ${this.escapeHtml(data.tool_name)}: ${this.escapeHtml(JSON.stringify(result).substring(0, 100))}</p>`
      } else {
        toolDiv.className = 'mb-2 p-3 bg-red-50 border border-red-200 rounded-lg'
        toolDiv.innerHTML = `<p class="text-xs text-red-600">❌ ${this.escapeHtml(data.tool_name)}: ${this.escapeHtml(result.error || 'Failed')}</p>`
      }
    }
    this.scrollToBottom()
  }

  private handleConfirmationRequired(data: any): void {
    // Show confirmation modal
    this.showConfirmationModal(data)
  }

  private showConfirmationModal(data: any): void {
    // Remove existing modal
    const existing = document.getElementById('confirmation-modal')
    existing?.remove()

    const modal = document.createElement('div')
    modal.id = 'confirmation-modal'
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center bg-black/50'
    
    const toolName = this.formatToolName(data.tool_name)
    const argsText = this.formatArguments(data.arguments)
    
    modal.innerHTML = `
      <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full mx-4 overflow-hidden">
        <div class="p-6 border-b border-border/50">
          <div class="flex items-center gap-3">
            <div class="w-12 h-12 rounded-full bg-amber-100 flex items-center justify-center">
              ${WARNING_ICON}
            </div>
            <div>
              <h3 class="text-lg font-semibold text-primary">Confirmation Required</h3>
              <p class="text-sm text-muted">High-risk action needs your approval</p>
            </div>
          </div>
        </div>
        <div class="p-6">
          <div class="bg-surface-elevated rounded-xl p-4 mb-4">
            <p class="text-sm font-medium text-primary mb-2">${toolName}</p>
            <pre class="text-xs text-muted whitespace-pre-wrap">${argsText}</pre>
          </div>
          <div class="flex gap-3">
            <button id="confirm-cancel" class="flex-1 px-4 py-2 border border-border/50 rounded-xl text-muted hover:bg-surface-elevated transition-colors">
              Cancel
            </button>
            <button id="confirm-approve" class="flex-1 px-4 py-2 bg-gradient-to-r from-primary to-secondary text-white rounded-xl hover:shadow-lg transition-all">
              Approve
            </button>
          </div>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    
    // Add event listeners
    modal.querySelector('#confirm-cancel')?.addEventListener('click', () => {
      this.sendConfirmation(data.audit_id, false)
      modal.remove()
    })
    
    modal.querySelector('#confirm-approve')?.addEventListener('click', () => {
      this.sendConfirmation(data.audit_id, true)
      modal.remove()
    })
    
    // Close on background click
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        this.sendConfirmation(data.audit_id, false)
        modal.remove()
      }
    })
  }

  private async sendConfirmation(auditId: number, confirmed: boolean): Promise<void> {
    try {
      const response = await fetch('/api/v1/ai_chat/confirm_tool', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          audit_id: auditId,
          confirmed: confirmed
        })
      })
      
      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to send confirmation')
      }
      
    } catch (error: any) {
      this.handleError(error.message)
    }
  }

  private handleToolConfirmed(data: any): void {
    // Update any existing tool indicator
    const toolDiv = document.getElementById('tool-call-indicator')
    if (toolDiv) {
      toolDiv.className = 'mb-2 p-3 bg-green-50 border border-green-200 rounded-lg'
      toolDiv.innerHTML = `<p class="text-xs text-green-600">✅ ${this.escapeHtml(data.tool_name)} executed successfully!</p>`
    }
    this.scrollToBottom()
  }

  private handleToolRejected(data: any): void {
    const toolDiv = document.getElementById('tool-call-indicator')
    if (toolDiv) {
      toolDiv.className = 'mb-2 p-3 bg-gray-50 border border-gray-200 rounded-lg'
      toolDiv.innerHTML = `<p class="text-xs text-gray-600">⏹️ ${this.escapeHtml(data.tool_name)} was rejected</p>`
    }
    this.scrollToBottom()
  }

  private formatToolName(name: string): string {
    return name.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ')
  }

  private formatArguments(args: any): string {
    try {
      return JSON.stringify(args, null, 2)
    } catch {
      return String(args)
    }
  }

  private showTypingIndicator(): void {
    this.hideTypingIndicator()
    const indicator = document.createElement('div')
    indicator.id = 'typing-indicator'
    indicator.className = 'message assistant mb-4 flex justify-start'
    indicator.innerHTML = `${this.wrapHtml()}
      <div class="flex flex-row items-start gap-3 max-w-3xl">
        <div class="flex-shrink-0">
          <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center"> 
            ${BOT_AVATAR}
          </div>
        </div>
        <div class="text-left">
          <div class="inline-block p-4 rounded-2xl bg-white border border-border/50 shadow-sm">
            <div class="flex gap-1">
              <span class="w-2 h-2 bg-primary rounded-full animate-bounce" style="animation-delay: 0ms;"></span>
              <span class="w-2 h-2 bg-primary rounded-full animate-bounce" style="animation-delay: 150ms;"></span>
              <span class="w-2 h-2 bg-primary rounded-full animate-bounce" style="animation-delay: 300ms;"></span>
            </div>
          </div>
        </div>
      </div>${this.wrapHtmlEnd()}`
    this.messagesContainerTarget.appendChild(indicator)
    this.scrollToBottom()
  }

  private hideTypingIndicator(): void {
    const indicator = document.getElementById('typing-indicator')
    indicator?.remove()
  }

  private appendChunk(chunk: string, messageId: number): void {
    let messageEl = this.currentAssistantMessage
    if (!messageEl) {
      messageEl = this.createAssistantMessageElement()
      this.messagesContainerTarget.appendChild(messageEl)
      this.currentAssistantMessage = messageEl
    }
    const contentEl = messageEl.querySelector('.message-content')
    if (contentEl) {
      contentEl.innerHTML += this.escapeHtml(chunk)
      this.scrollToBottom()
    }
  }

  private createAssistantMessageElement(): HTMLElement {
    const div = document.createElement('div')
    div.className = 'message assistant mb-4 flex justify-start'
    div.innerHTML = `${this.wrapHtml()}
      <div class="flex flex-row items-start gap-3 max-w-3xl">
        <div class="flex-shrink-0">
          <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
            ${BOT_AVATAR}
          </div>
        </div>
        <div class="text-left">
          <div class="inline-block p-4 rounded-2xl bg-white border border-border/50 shadow-sm">
            <p class="text-sm message-content"></p>
          </div>
          <p class="text-xs text-muted mt-1">AI - ${new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</p>
        </div>
      </div>${this.wrapHtmlEnd()}`
    return div
  }

  // Text-to-Speech: Speak the AI response
  private speakResponse(text: string): void {
    if (!('speechSynthesis' in window)) {
      console.log("[AIChat] Text-to-speech not supported")
      return
    }

    // Cancel any ongoing speech
    window.speechSynthesis.cancel()

    // Strip emojis and problematic characters before speaking
    const cleanText = text.replace(/[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}]/gu, '').trim()
    
    if (!cleanText || cleanText.length === 0) {
      return
    }

    const utterance = new SpeechSynthesisUtterance(cleanText)
    utterance.lang = 'en-US'
    utterance.rate = 1.0
    utterance.pitch = 1.0

    // Try to get an English voice
    const voices = window.speechSynthesis.getVoices()
    const englishVoice = voices.find(v => v.lang.startsWith('en'))
    if (englishVoice) {
      utterance.voice = englishVoice
    }

    utterance.onerror = (e) => {
      console.log("[AIChat] Speech error:", e.error)
    }

    console.log("[AIChat] Speaking response:", cleanText.substring(0, 50))
    window.speechSynthesis.speak(utterance)
  }

  private handleComplete(data: any): void {
    this.isGenerating = false
    this.hideTypingIndicator()
    this.showStopButton(false)
    this.setLoading(false)
    this.inputTarget.disabled = false
    
    // If there's a complete content, ensure it's rendered
    if (data.content) {
      const msgEl = this.currentAssistantMessage
      if (msgEl) {
        const contentEl = msgEl.querySelector('.message-content')
        if (contentEl && !contentEl.innerHTML) {
          contentEl.innerHTML = this.escapeHtml(data.content)
        }
      }
      
      // Speak the AI response if voice is enabled
      const voiceBtn = document.getElementById('voice-chat-btn')
      if (voiceBtn && voiceBtn.classList.contains('bg-success')) {
        this.speakResponse(data.content)
      }
    }
    
    this.currentAssistantMessage = null
    this.abortController = null
  }

  private handleError(error: string): void {
    this.isGenerating = false
    this.hideTypingIndicator()
    this.showStopButton(false)
    this.setLoading(false)
    this.inputTarget.disabled = false
    this.currentAssistantMessage = null
    this.abortController = null
    
    const errorDiv = document.createElement('div')
    errorDiv.className = 'mb-4 p-4 bg-red-50 border border-red-200 rounded-xl'
    errorDiv.innerHTML = `<p class="text-sm text-red-600">Error: ${this.escapeHtml(error)}</p>`
    this.messagesContainerTarget.appendChild(errorDiv)
    this.scrollToBottom()
  }

  private escapeHtml(text: string): string {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  private showStopButton(show: boolean): void {
    const existingBtn = document.getElementById('stop-generation-btn')
    if (!show) {
      existingBtn?.remove()
      return
    }
    if (existingBtn) return

    const btn = document.createElement('button')
    btn.id = 'stop-generation-btn'
    btn.className = 'fixed bottom-24 right-8 z-50 flex items-center gap-2 px-4 py-2 bg-red-500 text-white rounded-full shadow-lg hover:bg-red-600 transition-all'
    btn.innerHTML = `${STOP_ICON} Stop`
    btn.onclick = () => this.stopGeneration()
    document.body.appendChild(btn)
  }

  stopGeneration(): void {
    this.abortController?.abort()
    this.isGenerating = false
    this.showStopButton(false)
    this.setLoading(false)
    this.inputTarget.disabled = false
    this.hideTypingIndicator()
    this.currentAssistantMessage = null
  }

  showAutopilot(): void {
    this.messagesContainerTarget.innerHTML = this.buildAutopilotPanelHtml()
  }

  private buildAutopilotPanelHtml(): string {
    return `${this.wrapHtml()}
      <div class="flex flex-col h-full">
        <div class="flex items-center justify-between p-4 border-b border-border/50">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
              ${BOT_AVATAR}
            </div>
            <div>
              <h3 class="font-semibold text-primary">AI Autopilot</h3>
              <p class="text-xs text-muted">Your marketing assistant</p>
            </div>
          </div>
          <button class="p-2 hover:bg-surface rounded-lg transition-colors"
            data-action="ai-chat#hideAutopilot">${CLOSE_ICON}</button>
        </div>
        <div id="autopilot-messages" class="flex-1 p-4 overflow-y-auto"></div>
        <div class="p-4 border-t border-border/50">
          <form id="autopilot-form" class="flex gap-2">${this.buildAutopilotForm()}</form>
        </div>
      </div>${this.wrapHtmlEnd()}`
  }

  private wrapHtml(): string {
    return '<div class="flex flex-col h-full">'
  }

  private wrapHtmlEnd(): string {
    return '</div>'
  }

  private buildAutopilotForm(): string {
    return `<input type="text" id="autopilot-input"
      class="flex-1 px-4 py-2 bg-white border border-border/50 rounded-xl focus:ring-2 focus:ring-primary/20 focus:border-primary resize-none"
      placeholder="Ask Autopilot anything..." />
      <button type="submit" class="p-2 bg-gradient-to-r from-primary to-secondary text-white rounded-xl hover:shadow-lg transition-all">
        ${SEND_ICON}
      </button>`
  }

  hideAutopilot(): void {
    this.messagesContainerTarget.innerHTML = this.buildDefaultChatHtml()
  }

  private buildDefaultChatHtml(): string {
    return `${this.wrapHtml()}
      <div class="flex flex-col items-center justify-center h-full">
        <div class="w-20 h-20 rounded-full bg-gradient-to-br from-primary/20 to-secondary/20 flex items-center justify-center mb-4 shadow-lg">
          <svg class="w-10 h-10 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z">
            </path>
          </svg>
        </div>
        <h3 class="text-xl font-bold text-primary mb-2">AI Marketing Assistant</h3>
        <p class="text-muted text-center max-w-md mb-6">
          Ask me anything about content creation, scheduling, or marketing strategy
        </p>
        <div class="flex flex-wrap justify-center gap-2">
          <button class="${QUICK_PROMPT_CLASS}"
            data-prompt="Help me create a social media strategy for my new product launch">
            New Product Launch
          </button>
          <button class="${QUICK_PROMPT_CLASS}"
            data-prompt="Generate engaging content ideas for Instagram posts">
            Instagram Ideas
          </button>
          <button class="${QUICK_PROMPT_CLASS}"
            data-prompt="Help me optimize my existing campaigns for better engagement">
            Optimize Campaigns
          </button>
        </div>
      </div>${this.wrapHtmlEnd()}`
  }

  createNewConversation(): void {
    const form = document.createElement("form")
    form.method = "POST"
    form.action = "/ai_chat"
    form.style.display = "none"
    document.body.appendChild(form)
    form.submit()
  }

  sendMessage(event: Event): void {
    event.preventDefault()
    const message = this.inputTarget.value.trim()
    if (!message || this.isGenerating) return

    // Use streaming API if conversation ID is available
    if (this.conversationIdValue) {
      this.sendMessageStreaming(message)
    } else {
      this.setLoading(true)
      this.appendMessage(message, "user")
      this.inputTarget.value = ""

      this.formTarget.method = "POST"
      this.formTarget.action = "/ai_chat"
      this.formTarget.submit()
    }
  }

  private async sendMessageStreaming(message: string): Promise<void> {
    this.isGenerating = true
    this.setLoading(true)
    this.inputTarget.disabled = true
    this.appendMessage(message, "user")
    this.inputTarget.value = ""
    this.showStopButton(true)
    this.abortController = new AbortController()

    try {
      const response = await fetch('/api/v1/ai_chat/stream_message', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          conversation_id: this.conversationIdValue,
          message: message
        }),
        signal: this.abortController.signal
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to send message')
      }

      // Response will be handled via ActionCable streaming
      
    } catch (error: any) {
      if (error.name === 'AbortError') {
        this.handleError('Generation stopped')
      } else {
        this.handleError(error.message)
      }
    }
  }

  appendMessage(content: string, role: string): void {
    const div = document.createElement("div")
    const justifyClass = role === "user" ? "justify-end" : "justify-start"
    const avatar = role === "user" ? USER_AVATAR : BOT_AVATAR
    const bgClass = (
      role === "user"
        ? "bg-gradient-to-br from-primary to-secondary text-white"
        : "bg-white border border-border/50"
    )
    const flexClass = role === "user" ? "flex-row-reverse" : "flex-row"
    const avatarBg = role === "user" ? "from-primary to-secondary" : "from-purple-500 to-pink-500"
    const textClass = role === "user" ? "text-white" : "text-primary"
    const alignClass = role === "user" ? "text-right" : "text-left"
    const senderName = role === "user" ? "You" : "AI"
    const time = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })

    div.className = `message ${role} mb-4 flex ${justifyClass}`
    div.innerHTML = `${this.wrapHtml()}
      <div class="flex ${flexClass} items-start gap-3 max-w-3xl">
        <div class="flex-shrink-0">
          <div class="w-10 h-10 rounded-xl bg-gradient-to-br ${avatarBg} flex items-center justify-center">
            ${avatar}
          </div>
        </div>
        <div class="${alignClass}">
          <div class="inline-block p-4 rounded-2xl ${bgClass} shadow-sm">
            <p class="text-sm">${content}</p>
          </div>
          <p class="text-xs text-muted mt-1">${senderName} - ${time}</p>
        </div>
      </div>${this.wrapHtmlEnd()}`

    this.messagesContainerTarget.appendChild(div)
    this.scrollToBottom()
  }

  handleKeydown(event: KeyboardEvent): void {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage(event)
    }
  }

  private setLoading(loading: boolean): void {
    this.sendBtnTarget.disabled = loading
    this.sendBtnTarget.innerHTML = loading ? SPINNER : SEND_ICON
  }

  private scrollToBottom(): void {
    this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
  }
}
