import { Controller } from "@hotwired/stimulus"
// @ts-ignore - showToast is exposed globally
declare const showToast: (message: string, type?: string) => void

// Connects to data-controller="ai-content"
export default class extends Controller {
  // stimulus-validator: disable-next-line
  static targets = ["topic", "brandVoice", "platform", "contentType", "additionalContext", "result", "outputFormat", "useCustomPrompt", "customPromptSection", "customPrompt"]

  // stimulus-validator: disable-next-line
  declare readonly topicTarget: HTMLTextAreaElement
  // stimulus-validator: disable-next-line
  declare readonly brandVoiceTarget: HTMLSelectElement
  // stimulus-validator: disable-next-line
  declare readonly platformTarget: HTMLSelectElement
  // stimulus-validator: disable-next-line
  declare readonly contentTypeTarget: HTMLSelectElement
  // stimulus-validator: disable-next-line
  declare readonly additionalContextTarget: HTMLTextAreaElement
  // stimulus-validator: disable-next-line
  declare readonly resultTarget: HTMLElement
  // stimulus-validator: disable-next-line
  declare readonly outputFormatTarget: HTMLSelectElement
  // stimulus-validator: disable-next-line
  declare readonly useCustomPromptTarget: HTMLInputElement
  // stimulus-validator: disable-next-line
  declare readonly customPromptSectionTarget: HTMLElement
  // stimulus-validator: disable-next-line
  declare readonly customPromptTarget: HTMLTextAreaElement

  async generate(event: Event) {
    const form = (event.target as HTMLElement).closest('form') as HTMLFormElement | null
    if (!form) return

    const topic = this.topicTarget.value.trim()
    if (!topic) {
      showToast?.('Please enter a topic', 'error')
      this.topicTarget.focus()
      return
    }

    // Use standard form submission - Turbo will handle the response
    form.submit()

    // Show loading indicator
    const loadingEl = document.getElementById('loading')
    const btnEl = document.getElementById('generate_button')
    if (loadingEl) loadingEl.classList.remove('hidden')
    if (btnEl) {
      const btn = btnEl.querySelector('button') as HTMLButtonElement | null
      if (btn) {
        btn.disabled = true
        btn.classList.add('opacity-50', 'cursor-not-allowed')
      }
    }
  }

  toggleCustomPrompt() {
    if (this.useCustomPromptTarget?.checked) {
      this.customPromptSectionTarget?.classList.remove('hidden')
    } else {
      this.customPromptSectionTarget?.classList.add('hidden')
    }
  }

  regenerate(event: Event) {
    const button = event.currentTarget as HTMLButtonElement
    const form = button.closest('form') as HTMLFormElement | null
    if (!form) return

    button.disabled = true
    button.classList.add('opacity-50', 'cursor-not-allowed')

    form.requestSubmit(button)
  }
}
