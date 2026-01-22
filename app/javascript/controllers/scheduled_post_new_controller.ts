import { Controller } from "@hotwired/stimulus"

/**
 * Scheduled Post New Controller
 *
 * Handles content selection in new scheduled post form
 */

// stimulus-validator: allow-script
export default class extends Controller<HTMLElement> {
  static targets = ["contentCard", "contentRadio"]

  // Declare targets
  declare readonly contentCardTargets: HTMLElement[]
  declare readonly contentRadioTargets: HTMLInputElement[]

  connect() {
    // Add event listeners to content cards
    this.contentCardTargets.forEach((card: HTMLElement) => {
      card.addEventListener('click', this.selectContent.bind(this))
    })
  }

  selectContent(event: Event) {
    const card = event.currentTarget as HTMLElement
    const contentId = card.dataset.contentId
    
    if (contentId) {
      const radio = this.element.querySelector(`input[name="content_id"][value="${contentId}"]`) as HTMLInputElement
      if (radio) {
        radio.checked = true
        
        // Remove selected class from all cards
        this.contentCardTargets.forEach((target: HTMLElement) => {
          target.classList.remove('border-purple-500', 'bg-purple-50')
        })
        
        // Add selected class to clicked card
        card.classList.add('border-purple-500', 'bg-purple-50')
      }
    }
  }
}