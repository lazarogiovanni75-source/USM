import { Controller } from "@hotwired/stimulus"

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

// stimulus-validator: disable-next-line
export default class extends Controller<HTMLElement> {
  static targets = ["form", "input", "messagesContainer", "sendBtn"]

  declare readonly formTarget: HTMLFormElement
  declare readonly inputTarget: HTMLTextAreaElement
  declare readonly messagesContainerTarget: HTMLElement
  declare readonly sendBtnTarget: HTMLButtonElement

  private autopilotConversationId: string | null = null
  private isRecording: boolean = false

  connect(): void {
    console.log("AI Chat controller connected")
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
    if (!message) return

    this.setLoading(true)
    this.appendMessage(message, "user")
    this.inputTarget.value = ""

    this.formTarget.method = "POST"
    this.formTarget.action = "/ai_chat"
    this.formTarget.submit()
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

  private setLoading(loading: boolean): void {
    this.sendBtnTarget.disabled = loading
    this.sendBtnTarget.innerHTML = loading ? SPINNER : SEND_ICON
  }

  private scrollToBottom(): void {
    this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
  }
}
