import { Controller } from "@hotwired/stimulus"

// PilotChatToggleController - Simple toggle for pilot chat visibility
export default class PilotChatToggleController extends Controller<HTMLElement> {
  private isOpen = false

  toggleChat(): void {
    this.isOpen = !this.isOpen
    // Trigger a custom event that can be listened to
    this.dispatch("toggle", { detail: { isOpen: this.isOpen } })
  }
}
