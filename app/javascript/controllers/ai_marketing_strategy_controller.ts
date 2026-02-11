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
}
