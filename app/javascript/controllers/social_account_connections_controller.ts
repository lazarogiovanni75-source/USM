import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static targets = ["refreshBtn"]

  declare readonly refreshBtnTarget: HTMLButtonElement

  connect(): void {
    console.log("SocialAccountConnections connected")
  }

  disconnect(): void {
    console.log("SocialAccountConnections disconnected")
  }
}
