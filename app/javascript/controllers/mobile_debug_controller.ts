import { Controller } from "@hotwired/stimulus"

/**
 * Mobile Debug Controller
 * Shows visible debug panel at bottom of screen for mobile debugging
 * Targets: none
 * Actions: none (auto-monitors form submissions)
 */
export default class extends Controller {
  private debugPanel: HTMLElement | null = null

  connect() {
    this.createDebugPanel()
    this.log('🔍 Mobile Debug Panel Active', 'success')
    this.monitorForms()
  }

  disconnect() {
    if (this.debugPanel) {
      this.debugPanel.remove()
    }
  }

  private createDebugPanel() {
    this.debugPanel = document.createElement('div')
    this.debugPanel.style.cssText = `
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      max-height: 250px;
      overflow-y: auto;
      background: rgba(0, 0, 0, 0.95);
      color: #0f0;
      font-family: 'Courier New', monospace;
      font-size: 10px;
      padding: 8px;
      z-index: 999999;
      border-top: 2px solid #0f0;
      box-shadow: 0 -4px 20px rgba(0, 255, 0, 0.3);
    `
    document.body.appendChild(this.debugPanel)
  }

  private log(message: string, type: 'info' | 'error' | 'success' | 'warning' = 'info') {
    if (!this.debugPanel) return

    const colors = {
      'info': '#0ff',
      'error': '#f00',
      'success': '#0f0',
      'warning': '#ff0'
    }

    const icons = {
      'info': 'ℹ️',
      'error': '❌',
      'success': '✅',
      'warning': '⚠️'
    }

    const line = document.createElement('div')
    line.style.color = colors[type]
    line.style.marginBottom = '4px'
    line.style.lineHeight = '1.4'
    line.textContent = `${icons[type]} [${new Date().toLocaleTimeString()}] ${message}`
    
    this.debugPanel.appendChild(line)
    this.debugPanel.scrollTop = this.debugPanel.scrollHeight
  }

  private monitorForms() {
    // Monitor ALL form submissions
    document.addEventListener('submit', (e) => {
      const form = e.target as HTMLFormElement
      const action = form.action || 'unknown'
      const method = form.method || 'POST'
      
      this.log(`📤 Form Submit: ${method} ${action}`, 'info')
      
      // Log form data
      const formData = new FormData(form)
      const data: Record<string, any> = {}
      formData.forEach((value, key) => {
        if (key !== 'authenticity_token') {
          data[key] = value
        }
      })
      
      this.log(`📝 Form Data: ${JSON.stringify(data).substring(0, 100)}...`, 'info')
    })

    // Monitor Turbo Stream responses
    document.addEventListener('turbo:submit-end', (e: any) => {
      const detail = e.detail
      const success = detail.success
      
      if (success) {
        this.log('✅ Turbo Submit Success', 'success')
      } else {
        this.log('❌ Turbo Submit Failed', 'error')
      }
    })

    // Monitor fetch errors
    document.addEventListener('turbo:fetch-request-error', (e: any) => {
      this.log(`❌ Fetch Error: ${e.detail?.error || 'Unknown'}`, 'error')
    })

    // Monitor frame errors
    document.addEventListener('turbo:frame-missing', (e: any) => {
      this.log(`❌ Frame Missing: ${e.detail?.response || 'Unknown'}`, 'error')
    })

    // Monitor AJAX errors (if any)
    const originalFetch = window.fetch
    window.fetch = async (...args) => {
      const url = typeof args[0] === 'string' ? args[0] : (args[0] as Request).url
      this.log(`🌐 Fetch: ${url}`, 'info')
      
      try {
        const response = await originalFetch(...args)
        if (response.ok) {
          this.log(`✅ Fetch OK: ${response.status}`, 'success')
        } else {
          this.log(`❌ Fetch Error: ${response.status} ${response.statusText}`, 'error')
        }
        return response
      } catch (error) {
        this.log(`❌ Fetch Failed: ${error}`, 'error')
        throw error
      }
    }

    // Log any console errors
    const originalError = console.error
    console.error = (...args) => {
      this.log(`❌ Console Error: ${args.join(' ')}`, 'error')
      originalError.apply(console, args)
    }
  }
}
