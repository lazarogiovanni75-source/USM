import { Controller } from "@hotwired/stimulus"

// AI Marketing Strategy Controller - Handles strategy Q&A interactions
// Uses form submission for Turbo Stream compatibility
export default class AiMarketingStrategyController extends Controller {
  // stimulus-validator: disable-next-line
  static targets = ["question", "result", "submitBtn"]
  
  declare readonly questionTarget: HTMLTextAreaElement
  declare readonly resultTarget: HTMLElement
  declare readonly submitBtnTarget: HTMLButtonElement
  
  prepareQuestion(event: Event): void {
    // Form preparation hook - nothing needed for Turbo Stream
  }
  
  askAI(event: Event): void {
    const question = this.questionTarget.value.trim()
    if (!question) {
      event.preventDefault()
      return
    }
    
    // Disable button during submission
    this.submitBtnTarget.disabled = true
    this.submitBtnTarget.innerHTML = '<span class="animate-spin mr-2">⏳</span> Thinking...'
    
    // Form will submit via Turbo Stream - no manual handling needed
  }
  
  // Reset button after Turbo Stream response (called automatically by Turbo)
  reconnect() {
    // Reset button state if needed
    if (this.submitBtnTarget.disabled) {
      this.submitBtnTarget.disabled = false
      this.submitBtnTarget.innerHTML = '<svg class="lucide lucide-send w-4 h-4 mr-2" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/></svg> Ask AI'
    }
  }
}
