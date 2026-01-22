import { Controller } from "@hotwired/stimulus"

/**
 * Content New Controller
 *
 * Handles content creation form functionality including character counting and AI suggestions
 */

// stimulus-validator: system-controller
export default class extends Controller<HTMLElement> {
  static targets = ["textarea", "charCount", "preview"]

  // Declare targets
  declare readonly textareaTarget: HTMLTextAreaElement
  declare readonly charCountTarget: HTMLElement
  declare readonly previewTarget: HTMLElement

  connect(): void {
    this.setupCharacterCounter()
    this.setupLivePreview()
  }

  private setupCharacterCounter(): void {
    this.textareaTarget.addEventListener('input', () => {
      const count = this.textareaTarget.value.length
      this.charCountTarget.textContent = count.toString()
      
      // Update color based on character count
      if (count > 280 && this.textareaTarget.value.includes('twitter')) {
        this.charCountTarget.className = 'text-sm text-red-500'
      } else if (count > 2200) {
        this.charCountTarget.className = 'text-sm text-yellow-500'
      } else {
        this.charCountTarget.className = 'text-sm text-gray-500'
      }
    })
  }

  private setupLivePreview(): void {
    this.textareaTarget.addEventListener('input', () => {
      const content = this.textareaTarget.value
      if (content.trim()) {
        this.previewTarget.innerHTML = `
          <div class="text-gray-900">
            <div class="text-sm text-gray-500 mb-2">Preview:</div>
            <div class="whitespace-pre-wrap">${content}</div>
          </div>
        `
      } else {
        this.previewTarget.innerHTML = '<div class="text-sm text-gray-500">Your content preview will appear here as you type...</div>'
      }
    })
  }

  // AI suggestions functionality
  generateAISuggestions(): void {
    const content = this.textareaTarget.value
    if (!content.trim()) {
      // TODO: Replace with toast notification
      console.log('Please enter some content first to get AI suggestions.')
      return
    }

    // This would integrate with your AI service
    console.log('AI suggestions feature will be available after configuring the OpenAI integration.')
  }
}