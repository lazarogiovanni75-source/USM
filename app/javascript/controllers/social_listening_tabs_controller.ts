import { Controller } from "@hotwired/stimulus"

// stimulus-validator: disable-next-line
export default class SocialListeningTabsController extends Controller {
  // stimulus-validator: disable-next-line
  static targets = ["section", "button"]

  // stimulus-validator: disable-next-line
  declare readonly sectionTargets: HTMLElement[]
  // stimulus-validator: disable-next-line
  declare readonly buttonTargets: HTMLButtonElement[]

  initialize(): void {
    this.showSectionFromButton(this.buttonTargets[0])
  }

  showSection(event: MouseEvent): void {
    const button = event.currentTarget as HTMLButtonElement
    this.showSectionFromButton(button)
  }

  private showSectionFromButton(button: HTMLButtonElement): void {
    const section = button.dataset["section"] || "keywords"

    this.sectionTargets.forEach(el => {
      el.classList.add("hidden")
    })

    this.buttonTargets.forEach(btn => {
      btn.classList.remove("text-purple-600", "border-b-2", "border-purple-600")
      btn.classList.add("text-gray-500")
    })

    const targetSection = document.getElementById(`section-${section}`)
    if (targetSection) {
      targetSection.classList.remove("hidden")
    }

    button.classList.add("text-purple-600", "border-b-2", "border-purple-600")
    button.classList.remove("text-gray-500")
  }
}