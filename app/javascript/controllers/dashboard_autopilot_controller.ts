import { Controller } from "@hotwired/stimulus"

const USER_AVATAR =
  "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'>" +
  "<path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' " +
  "d='M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z'>" +
  "</path></svg>"

const BOT_AVATAR =
  "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'>" +
  "<path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' " +
  "d='M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3" +
  "m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 " +
  "3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754" +
  "-.988-2.386l-.548-.547z'></path></svg>"

const SPINNER =
  "<svg class='w-5 h-5 animate-spin' fill='none' stroke='currentColor' viewBox='0 0 24 24'>" +
  "<circle class='opacity-25' cx='12' cy='12' r='10' stroke='currentColor' stroke-width='4'></circle>" +
  "<path class='opacity-75' fill='currentColor' d='M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z'></path></svg>"

const SEND_ICON =
  "<svg class='w-5 h-5' fill='none' stroke='currentColor' viewBox='0 0 24 24'>" +
  "<path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' " +
  "d='M12 19l9 2-9-18-9 18 9-2zm0 0v-8'></path></svg>"

export default class DashboardAutopilotController extends Controller {
  static targets = [
    "form",
    "input",
    "messagesContainer",
    "conversationId"
  ]

  declare readonly formTarget: HTMLFormElement
  declare readonly inputTarget: HTMLTextAreaElement
  declare readonly messagesContainerTarget: HTMLElement
  declare readonly conversationIdTarget: HTMLInputElement
  declare readonly sendBtnTarget: HTMLButtonElement

  private autopilotConversationId: string | null = null

  connect() {
    this.autopilotConversationId = this.conversationIdTarget.value || null
    if (this.autopilotConversationId) {
      this.loadMessagesViaTurbo()
    } else {
      this.messagesContainerTarget.innerHTML = this.getEmptyState()
    }
  }

  loadMessagesViaTurbo() {
    if (!this.autopilotConversationId) return
    const url = `/ai_chat/${this.autopilotConversationId}`
    const xhr = new XMLHttpRequest()
    xhr.open("GET", url, true)
    xhr.setRequestHeader("Accept", "text/html")
    xhr.onload = () => {
      if (xhr.status === 200) {
        const parser = new DOMParser()
        const doc = parser.parseFromString(xhr.responseText, "text/html")
        const newMessagesContainer = doc.querySelector("#chat-messages")
        if (newMessagesContainer) {
          this.messagesContainerTarget.innerHTML = newMessagesContainer.innerHTML
        }
      }
    }
    xhr.onerror = () => {
      console.error("Failed to load messages")
      this.messagesContainerTarget.innerHTML = this.getWelcomeMessage()
    }
    xhr.send()
  }

  createNewConversation() {
    const form = document.createElement("form")
    form.method = "POST"
    form.action = "/ai_chat"
    form.style.display = "none"
    document.body.appendChild(form)
    form.submit()
  }

  sendMessage(event: Event) {
    event.preventDefault()
    const message = this.inputTarget.value.trim()
    if (!message) return
    if (!this.autopilotConversationId) {
      this.createNewConversation()
      return
    }
    this.setLoading(true)
    this.addMessage(message, "user")
    this.inputTarget.value = ""
    const form = this.formTarget
    const formData = new FormData(form)
    formData.set("message", message)
    formData.set("conversation_id", this.autopilotConversationId)
    form.action = `/ai_chat/${this.autopilotConversationId}`
    form.method = "POST"
    form.submit()
  }

  addMessage(content: string, role: string) {
    const div = document.createElement("div")
    const justifyClass = role === "user" ? "justify-end" : "justify-start"
    const avatar = role === "user" ? USER_AVATAR : BOT_AVATAR
    const bgClass =
      role === "user"
        ? "bg-gradient-to-br from-primary to-secondary text-white"
        : "bg-white border border-border/50"
    const flexClass = role === "user" ? "flex-row-reverse" : "flex-row"
    const avatarBg =
      role === "user" ? "from-primary to-secondary" : "from-purple-500 to-pink-500"
    const textClass = role === "user" ? "text-white" : "text-primary"
    const alignClass = role === "user" ? "text-right" : "text-left"
    const senderName = role === "user" ? "You" : "Autopilot"

    div.className = `flex ${justifyClass}`
    div.innerHTML =
      `<div class="max-w-[85%]">` +
      `<div class="flex items-start gap-2 ${flexClass}">` +
      `<div class="w-8 h-8 rounded-full bg-gradient-to-br ${avatarBg} ` +
      `flex items-center justify-center flex-shrink-0">${avatar}</div>` +
      `<div class="${bgClass} rounded-2xl px-4 py-3 shadow-sm">` +
      `<p class="text-sm ${textClass}">${content}</p></div></div>` +
      `<p class="text-xs text-muted mt-1 ${alignClass}">${senderName} - Just now</p></div>`
    this.messagesContainerTarget.appendChild(div)
    this.scrollToBottom()
  }

  setLoading(loading: boolean) {
    this.sendBtnTarget.disabled = loading
    this.sendBtnTarget.innerHTML = loading ? SPINNER : SEND_ICON
  }

  scrollToBottom() {
    this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
  }

  getWelcomeMessage() {
    return `
      <div class="flex justify-start mb-4">
        <div class="flex items-start gap-2">
          <div class="w-8 h-8 rounded-full bg-gradient-to-br from-purple-500 to-pink-500
            flex items-center justify-center flex-shrink-0">${BOT_AVATAR}</div>
          <div class="bg-white border border-border/50 rounded-2xl rounded-tl-none
            px-4 py-3 shadow-sm">
            <p class="text-sm text-primary">
              Hi! I am your AI Autopilot. I can help you with social media management,
              content creation, scheduling, and analytics. How can I assist you today?
            </p>
          </div>
        </div>
        <p class="text-xs text-muted mt-1 ml-10">Autopilot - Just now</p>
      </div>`
  }

  getEmptyState() {
    return `
      <div class="flex flex-col items-center justify-center py-12">
        <div class="w-16 h-16 rounded-full bg-gradient-to-br from-purple-500/10 to-pink-500/10
          flex items-center justify-center mb-4">
          <svg class="w-8 h-8 text-primary" fill="none" stroke="currentColor"
            viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3
              m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374
              3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754
              -.988-2.386l-.548-.547z"></path>
          </svg>
        </div>
        <h3 class="text-lg font-semibold text-primary mb-1">Start a Conversation</h3>
        <p class="text-sm text-muted text-center mb-4">
          Chat with your AI Autopilot for instant assistance
        </p>
        <button type="button"
          data-action="dashboard-autopilot#createNewConversation"
          class="btn-primary">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
          </svg>
          New Chat
        </button>
      </div>`
  }

  renderMessages(
    messages: Array<{ content: string; role: string; created_at: string }>
  ) {
    if (messages.length === 0) {
      this.messagesContainerTarget.innerHTML = this.getWelcomeMessage()
      return
    }
    this.messagesContainerTarget.innerHTML = messages
      .map(msg => {
        const avatar = msg.role === "user" ? USER_AVATAR : BOT_AVATAR
        const justifyClass = msg.role === "user" ? "justify-end" : "justify-start"
        const flexClass = msg.role === "user" ? "flex-row-reverse" : "flex-row"
        const avatarBg =
          msg.role === "user"
            ? "from-primary to-secondary"
            : "from-purple-500 to-pink-500"
        const bgClass =
          msg.role === "user"
            ? "bg-gradient-to-br from-primary to-secondary text-white"
            : "bg-white border border-border/50"
        const textClass = msg.role === "user" ? "text-white" : "text-primary"
        const alignClass = msg.role === "user" ? "text-right" : "text-left"
        const senderName = msg.role === "user" ? "You" : "Autopilot"
        const time = new Date(msg.created_at).toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit"
        })
        return `
          <div class="flex ${justifyClass} mb-4">
            <div class="max-w-[85%]">
              <div class="flex items-start gap-2 ${flexClass}">
                <div class="w-8 h-8 rounded-full bg-gradient-to-br ${avatarBg}
                  flex items-center justify-center flex-shrink-0">${avatar}</div>
                <div class="${bgClass} rounded-2xl px-4 py-3 shadow-sm">
                  <p class="text-sm ${textClass}">${msg.content}</p>
                </div>
              </div>
              <p class="text-xs text-muted mt-1 ${alignClass}">
                ${senderName} - ${time}
              </p>
            </div>
          </div>`
      })
      .join("")
    this.scrollToBottom()
  }
}
