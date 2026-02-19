import { Controller } from "@hotwired/stimulus"

// Voice Toggle Controller - Handles the voice listening toggle on dashboard
export default class VoiceToggleController extends Controller {
  // Static targets for elements that exist in the HTML at page load
  static targets = ["button", "knob", "indicator", "status", "label"]

  declare readonly buttonTarget?: HTMLButtonElement
  declare readonly knobTarget?: HTMLElement
  declare readonly indicatorTarget?: HTMLElement
  declare readonly statusTarget?: HTMLElement
  declare readonly labelTarget?: HTMLElement

  private isEnabled: boolean = false

  connect(): void {
    this.loadState()
    console.log("VoiceToggle controller connected")
  }

  disconnect(): void {
    console.log("VoiceToggle controller disconnected")
  }

  toggle(event?: Event): void {
    event?.preventDefault()
    this.isEnabled = !this.isEnabled
    this.updateUI()
    this.saveState()
    this.notifyVoiceController()
  }

  private loadState(): void {
    const saved = localStorage.getItem("voice_enabled")
    if (saved !== null) {
      this.isEnabled = saved === "true"
    } else {
      const element = this.element as HTMLElement
      const dataEnabled = element.dataset.enabled
      if (dataEnabled === "true") {
        this.isEnabled = true
      }
    }
    this.updateUI()
  }

  private saveState(): void {
    localStorage.setItem("voice_enabled", String(this.isEnabled))
  }

  private updateUI(): void {
    // Handle toggle switch UI (in header)
    if (this.hasButtonTarget && this.hasKnobTarget && this.buttonTarget && this.knobTarget) {
      if (this.isEnabled) {
        this.buttonTarget.classList.remove("bg-gray-300")
        this.buttonTarget.classList.add("bg-success")
        this.knobTarget.classList.remove("translate-x-1")
        this.knobTarget.classList.add("translate-x-6")
        if (this.hasIndicatorTarget && this.indicatorTarget) {
          this.indicatorTarget.classList.remove("bg-gray-400")
          this.indicatorTarget.classList.add("bg-success", "animate-pulse")
        }
        if (this.hasLabelTarget && this.labelTarget) {
          this.labelTarget.textContent = "On"
        }
        this.buttonTarget.classList.add("ring-2", "ring-success/50")
      } else {
        this.buttonTarget.classList.remove("bg-success")
        this.buttonTarget.classList.add("bg-gray-300")
        this.knobTarget.classList.remove("translate-x-6")
        this.knobTarget.classList.add("translate-x-1")
        if (this.hasIndicatorTarget && this.indicatorTarget) {
          this.indicatorTarget.classList.remove("bg-success", "animate-pulse")
          this.indicatorTarget.classList.add("bg-gray-400")
        }
        if (this.hasLabelTarget && this.labelTarget) {
          this.labelTarget.textContent = "Off"
        }
        this.buttonTarget.classList.remove("ring-2", "ring-success/50")
      }
    }
  }

  private notifyVoiceController(): void {
    if (typeof window !== "undefined") {
      const event = new CustomEvent("voice:toggle", {
        detail: { enabled: this.isEnabled }
      })
      window.dispatchEvent(event)
    }
    if (this.isEnabled) {
      const voiceFloatBtn = document.getElementById("voice-float-btn")
      voiceFloatBtn?.click()
    }
  }

  private get hasButtonTarget(): boolean {
    return this.targets.has("button")
  }

  private get hasKnobTarget(): boolean {
    return this.targets.has("knob")
  }

  private get hasIndicatorTarget(): boolean {
    return this.targets.has("indicator")
  }

  private get hasLabelTarget(): boolean {
    return this.targets.has("label")
  }
}
