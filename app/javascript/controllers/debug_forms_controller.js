import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("[DebugForms] Connected")
    
    // Intercept all form submissions on the page
    document.addEventListener('submit', (event) => {
      const form = event.target
      console.log("[DebugForms] Form submitted:", {
        action: form.action,
        method: form.method,
        data: new FormData(form)
      })
      
      // Log form data
      const formData = new FormData(form)
      for (let [key, value] of formData.entries()) {
        console.log(`  ${key}: ${value}`)
      }
    })
    
    // Catch Turbo errors
    document.addEventListener('turbo:fetch-request-error', (event) => {
      console.error("[DebugForms] Turbo fetch error:", event.detail)
      alert(`Request failed: ${event.detail.error}`)
    })
    
    document.addEventListener('turbo:frame-missing', (event) => {
      console.error("[DebugForms] Turbo frame missing:", event.detail)
    })
  }
}
