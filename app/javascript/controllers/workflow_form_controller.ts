import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static targets = ["postNow", "scheduleOptions"]

  declare readonly postNowTarget: HTMLInputElement
  declare readonly scheduleOptionsTarget: HTMLElement

  connect(): void {
    console.log("Workflow form controller connected")
  }

  toggleScheduleOptions(): void {
    if (this.postNowTarget.checked) {
      this.scheduleOptionsTarget.classList.add('hidden')
    } else {
      this.scheduleOptionsTarget.classList.remove('hidden')
    }
  }
}
