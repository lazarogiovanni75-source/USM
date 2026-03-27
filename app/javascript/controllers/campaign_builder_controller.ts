import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  openModal(event: Event): void {
    const target = event.target as HTMLButtonElement
    const templateId = target.dataset.templateId
    const modal = document.getElementById('customize-modal')
    const modalContent = document.getElementById('modal-content')
    const modalTitle = document.getElementById('modal-title')
    
    if (modalTitle) modalTitle.textContent = 'Customize Your Campaign'
    const loadingHtml = '<div class="flex justify-center py-8"><div class="animate-spin w-8 h-8 border-4 border-primary border-t-transparent rounded-full"></div></div>'
    if (modalContent) modalContent.innerHTML = loadingHtml
    if (modal) modal.classList.remove('hidden')

    fetch(`/campaign_builder/customize_form?template_id=${templateId}`, {
      headers: {
        'Accept': 'text/html',
        'X-CSRF-Token': this.getCSRFToken()
      }
    })
      .then(response => response.text())
      .then(html => {
        if (modalContent) modalContent.innerHTML = html
      })
      .catch(error => {
        if (modalContent) {
          modalContent.innerHTML = '<p class="text-red-500">Failed to load form. Please try again.</p>'
        }
        console.error('Error:', error)
      })
  }

  closeModal(): void {
    const modal = document.getElementById('customize-modal')
    if (modal) {
      modal.classList.add('hidden')
    }
  }

  private getCSRFToken(): string {
    const token = document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement
    return token?.content || ""
  }
}
