import { Controller } from "@hotwired/stimulus"

/**
 * Content Creation Controller
 *
 * Handles AI content generation form submission using Turbo native form submission
 */

// stimulus-validator: user-controller
export default class extends Controller<HTMLElement> {
  static targets = ["topic", "contentType", "platform", "submitBtn"]

  declare readonly topicTarget: HTMLInputElement
  declare readonly contentTypeTarget: HTMLSelectElement
  declare readonly platformTarget: HTMLSelectElement
  declare readonly submitBtn: HTMLButtonElement

  private loading: boolean = false

  connect(): void {
    console.log("Content creation controller connected")
  }

  handleSubmit(event: Event): void {
    if (this.loading) {
      return
    }

    if (!this.topicTarget || !this.contentTypeTarget || !this.platformTarget) {
      console.error("Form targets not found")
      this.showError("Form configuration error")
      return
    }

    const topic = this.topicTarget.value.trim()
    if (!topic) {
      this.showError("Please enter a topic")
      return
    }

    this.setLoading(true)
  }

  publish(event: Event): void {
    event.preventDefault()
    
    const button = event.currentTarget as HTMLButtonElement
    const draftId = button.dataset.draftId
    
    if (!draftId) {
      this.showError("Draft not found")
      return
    }

    // Create form and submit
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = `/content_creation/publish_content/${draftId}`
    
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    if (csrfToken) {
      const tokenInput = document.createElement('input')
      tokenInput.type = 'hidden'
      tokenInput.name = 'authenticity_token'
      tokenInput.value = csrfToken
      form.appendChild(tokenInput)
    }

    document.body.appendChild(form)
    form.submit()
  }

  private setLoading(loading: boolean): void {
    if (!this.submitBtn) {
      console.warn("Submit button not found")
      return
    }
    this.loading = loading
    if (loading) {
      this.submitBtn.disabled = true
      this.submitBtn.innerHTML = `
        <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Generating...
      `
    } else {
      this.submitBtn.disabled = false
      this.submitBtn.innerHTML = `
        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
        </svg>
        Generate Content
      `
    }
  }

  private showError(message: string): void {
    const toast = document.createElement("div")
    toast.className = "fixed bottom-4 right-4 bg-red-500 text-white px-4 py-2 rounded-lg shadow-lg z-50 animate-pulse"
    toast.textContent = message
    document.body.appendChild(toast)

    setTimeout(() => {
      toast.remove()
    }, 3000)
  }

  private showSuccess(message: string): void {
    const toast = document.createElement("div")
    toast.className = "fixed bottom-4 right-4 bg-green-500 text-white px-4 py-2 rounded-lg shadow-lg z-50"
    toast.textContent = message
    document.body.appendChild(toast)

    setTimeout(() => {
      toast.remove()
    }, 3000)
  }
}
