import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  handleSubmit(event: Event): void {
    event.preventDefault()
  }

  preview(event: Event): void {
    event.preventDefault()
    const form = document.getElementById('campaign-customization-form') as HTMLFormElement | null
    if (!form) return

    const formData = new FormData(form)
    const params = new URLSearchParams(Array.from(formData.entries()) as unknown as [string, string][])
    const previewSection = document.getElementById('campaign-preview-section')
    const previewContent = document.getElementById('preview-content')
    
    const loadingHtml = '<div class="flex justify-center py-8"><div class="animate-spin w-8 h-8 border-4 border-primary border-t-transparent rounded-full"></div></div>'
    if (previewContent) previewContent.innerHTML = loadingHtml
    if (previewSection) previewSection.classList.remove('hidden')

    fetch(`/campaign_builder/preview?${params.toString()}`, {
      headers: {
        'Accept': 'text/html',
        'X-CSRF-Token': this.getCSRFToken()
      }
    })
      .then(response => response.text())
      .then(html => {
        if (previewContent) previewContent.innerHTML = html
      })
      .catch(error => {
        if (previewContent) {
          previewContent.innerHTML = '<p class="text-red-500">Failed to load preview. Please try again.</p>'
        }
        console.error('Error:', error)
      })
  }

  backToForm(): void {
    const previewSection = document.getElementById('campaign-preview-section')
    if (previewSection) {
      previewSection.classList.add('hidden')
    }
  }

  createCampaign(event: Event): void {
    event.preventDefault()
    const form = document.getElementById('campaign-customization-form') as HTMLFormElement | null
    if (!form) return

    const formData = new FormData(form)
    const params = new URLSearchParams(Array.from(formData.entries()) as unknown as [string, string][])
    
    fetch('/campaign_builder/create', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: params.toString()
    })
      .then(response => {
        if (response.redirected) {
          window.location.href = response.url
        } else {
          throw new Error('Failed to create campaign')
        }
      })
      .catch(error => {
        console.error('Error:', error)
      })
  }

  private getCSRFToken(): string {
    const token = document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement
    return token?.content || ""
  }
}
