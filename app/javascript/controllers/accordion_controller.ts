import { Controller } from "@hotwired/stimulus"

// Accordion controller for FAQ dropdowns
export default class AccordionController extends Controller {
  static targets = ["item", "content", "icon"]

  private itemTargets: HTMLElement[]
  private contentTarget: HTMLElement
  private iconTarget: HTMLElement

  toggle(event: Event): void {
    const trigger = event.currentTarget as HTMLElement
    const item = trigger.closest('[data-accordion-target="item"]') as HTMLElement
    const content = item.querySelector('[data-accordion-target="content"]') as HTMLElement
    const icon = item.querySelector('[data-accordion-target="icon"]') as HTMLElement

    const isOpen = item.classList.contains('open')

    if (isOpen) {
      // Close this item
      item.classList.remove('open')
      content.style.maxHeight = '0'
      if (icon) icon.classList.remove('rotate-180')
    } else {
      // Close all others first (single open mode)
      this.closeAll()

      // Open this item
      item.classList.add('open')
      content.style.maxHeight = content.scrollHeight + 'px'
      if (icon) icon.classList.add('rotate-180')
    }
  }

  closeAll(): void {
    this.itemTargets.forEach(item => {
      item.classList.remove('open')
      const content = item.querySelector('[data-accordion-target="content"]') as HTMLElement
      const icon = item.querySelector('[data-accordion-target="icon"]') as HTMLElement
      if (content) content.style.maxHeight = '0'
      if (icon) icon.classList.remove('rotate-180')
    })
  }

  openAll(): void {
    this.itemTargets.forEach(item => {
      item.classList.add('open')
      const content = item.querySelector('[data-accordion-target="content"]') as HTMLElement
      const icon = item.querySelector('[data-accordion-target="icon"]') as HTMLElement
      if (content) content.style.maxHeight = content.scrollHeight + 'px'
      if (icon) icon.classList.add('rotate-180')
    })
  }
}
