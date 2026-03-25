import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("[DebugForms] Connected")
    
    // Create visible debug panel
    this.createDebugPanel()
    
    // Intercept all form submissions on the page
    document.addEventListener('submit', (event) => {
      const form = event.target
      this.log(`Form submitted: ${form.action}`)
      
      // Log form data
      const formData = new FormData(form)
      for (let [key, value] of formData.entries()) {
        this.log(`  ${key}: ${value}`)
      }
    })
    
    // Catch Turbo errors
    document.addEventListener('turbo:fetch-request-error', (event) => {
      this.log(`ERROR: ${event.detail.error}`, 'error')
      alert(`Request failed: ${event.detail.error}`)
    })
    
    document.addEventListener('turbo:frame-missing', () => {
      this.log(`ERROR: Turbo frame missing`, 'error')
    })
    
    document.addEventListener('turbo:submit-end', (event) => {
      if (event.detail.success) {
        this.log('Form submitted successfully', 'success')
      } else {
        this.log('Form submission failed', 'error')
      }
    })
  }
  
  createDebugPanel() {
    const panel = document.createElement('div')
    panel.id = 'debug-panel'
    panel.style.cssText = `
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      max-height: 200px;
      overflow-y: auto;
      background: rgba(0,0,0,0.9);
      color: #0f0;
      font-family: monospace;
      font-size: 11px;
      padding: 10px;
      z-index: 99999;
      border-top: 2px solid #0f0;
    `
    document.body.appendChild(panel)
    this.debugPanel = panel
  }
  
  log(message, type = 'info') {
    if (!this.debugPanel) return
    
    const color = {
      'info': '#0f0',
      'error': '#f00',
      'success': '#0ff'
    }[type]
    
    const line = document.createElement('div')
    line.style.color = color
    line.textContent = `[${new Date().toLocaleTimeString()}] ${message}`
    this.debugPanel.appendChild(line)
    this.debugPanel.scrollTop = this.debugPanel.scrollHeight
  }
}
