import { Controller } from "@hotwired/stimulus"

// Policy Settings Controller - Handles policy configuration UI
export default class PolicySettingsController extends Controller {
  static targets = ["form"]

  connect(): void {
    console.log("Policy settings controller connected")
  }

  reset(): void {
    // Dispatch custom event for modal handling instead of using confirm()
    const event = new CustomEvent("policy:reset-request", {
      bubbles: true,
      detail: {
        message: "Are you sure you want to reset all settings to defaults?",
        onConfirm: () => this.performReset()
      }
    })
    this.element.dispatchEvent(event)
  }

  private performReset(): void {
    const resetForm = document.createElement("form")
    resetForm.method = "POST"
    resetForm.action = "/policy_settings/reset"
    
    const csrfToken = document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement
    const csrfInput = document.createElement("input")
    csrfInput.type = "hidden"
    csrfInput.name = "authenticity_token"
    csrfInput.value = csrfToken?.content || ""
    resetForm.appendChild(csrfInput)
    
    document.body.appendChild(resetForm)
    resetForm.submit()
  }
}
