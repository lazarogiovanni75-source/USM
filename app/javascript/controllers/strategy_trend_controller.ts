import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const url = this.element.getAttribute('data-strategy-trend-url')
    if (url) {
      // Use Turbo Frame to load content - Turbo will handle the response automatically
      this.element.innerHTML = `<turbo-frame id="strategy_trend" src="${url}">Loading...</turbo-frame>`
    }
  }
}
