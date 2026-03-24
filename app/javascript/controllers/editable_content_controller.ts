import { Controller } from "@hotwired/stimulus"
// @ts-ignore - showToast is exposed globally
declare const showToast: (message: string, type?: string) => void

// Connects to data-controller="editable-content"
export default class extends Controller {
  static values = {
    url: String,
    id: Number
  }

  declare readonly urlValue: string
  declare readonly idValue: number

  private displayElement: HTMLElement | null = null
  private editorElement: HTMLTextAreaElement | null = null
  private editContainer: HTMLElement | null = null
  private originalContent: string = ''

  connect() {
    this.displayElement = this.element.querySelector('[data-editable-content-target="display"]')
    this.editorElement = this.element.querySelector('[data-editable-content-target="editor"]')
    this.editContainer = this.element.querySelector('[id$="_edit"]')

    if (this.displayElement) {
      this.originalContent = this.displayElement.textContent?.trim() || ''
    }
  }

  edit() {
    if (!this.displayElement || !this.editorElement || !this.editContainer) {
      showToast?.('Editor not found', 'error')
      return
    }

    this.displayElement.closest('.prose')?.classList.add('hidden')
    this.editContainer.classList.remove('hidden')
    this.editorElement.focus()
  }

  cancel() {
    if (!this.displayElement || !this.editorElement || !this.editContainer) return

    this.editContainer.classList.add('hidden')
    this.displayElement.closest('.prose')?.classList.remove('hidden')
    this.editorElement.value = this.originalContent
  }

  save() {
    if (!this.editorElement || !this.urlValue) {
      showToast?.('Cannot save: missing URL', 'error')
      return
    }

    const newContent = this.editorElement.value.trim()
    if (!newContent) {
      showToast?.('Content cannot be empty', 'error')
      return
    }

    // Create a form and submit it for Turbo Stream response
    const form = document.createElement('form')
    form.method = 'post'
    form.action = this.urlValue

    const contentFieldInput = document.createElement('input')
    contentFieldInput.type = 'hidden'
    contentFieldInput.name = 'content_text'
    contentFieldInput.value = newContent
    form.appendChild(contentFieldInput)

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    if (csrfToken) {
      const csrfInput = document.createElement('input')
      csrfInput.type = 'hidden'
      csrfInput.name = 'authenticity_token'
      csrfInput.value = csrfToken
      form.appendChild(csrfInput)
    }

    // Find turbo-frame to submit within, or submit body
    const turboFrame = this.element.closest('turbo-frame') || document.body
    turboFrame.appendChild(form)

    // Submit form with Turbo
    form.style.display = 'none'
    form.submit()
  }
}
