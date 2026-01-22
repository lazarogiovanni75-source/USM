import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "tabButton",
    "tabContent", 
    "bulkApprove",
    "bulkReject",
    "contentCheckbox"
  ]

  declare readonly tabButtonTargets: HTMLElement[]
  declare readonly tabContentTargets: HTMLElement[]
  declare readonly bulkApproveTarget: HTMLElement
  declare readonly bulkRejectTarget: HTMLElement
  declare readonly contentCheckboxTargets: HTMLInputElement[]

  connect(): void {
    this.setupTabFunctionality()
    this.setupBulkActions()
  }

  private setupTabFunctionality(): void {
    this.tabButtonTargets.forEach(button => {
      button.addEventListener('click', (event) => {
        event.preventDefault()
        const tabName = button.dataset.tab!
        
        // Update active button
        this.tabButtonTargets.forEach(btn => {
          btn.classList.remove('active', 'border-purple-500', 'text-purple-600')
          btn.classList.add('border-transparent', 'text-gray-500')
        })
        
        button.classList.add('active', 'border-purple-500', 'text-purple-600')
        button.classList.remove('border-transparent', 'text-gray-500')
        
        // Show corresponding content
        this.tabContentTargets.forEach(content => {
          content.classList.add('hidden')
        })
        
        const tabContent = document.getElementById(`${tabName}-tab`)
        if (tabContent) {
          tabContent.classList.remove('hidden')
        }
      })
    })
  }

  private setupBulkActions(): void {
    this.bulkApproveTarget.addEventListener('click', (event) => {
      event.preventDefault()
      this.handleBulkApprove()
    })

    this.bulkRejectTarget.addEventListener('click', (event) => {
      event.preventDefault()
      this.handleBulkReject()
    })
  }

  private handleBulkApprove(): void {
    const selectedIds = this.contentCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.dataset.contentId)
      .filter(id => id !== undefined) as string[]
    
    if (selectedIds.length === 0) {
      // TODO: Replace with toast notification
      console.log('Please select content to approve.')
      return
    }
    
    this.submitBulkAction('/contents/bulk_approve', selectedIds)
  }

  private handleBulkReject(): void {
    const selectedIds = this.contentCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.dataset.contentId)
      .filter(id => id !== undefined) as string[]
    
    if (selectedIds.length === 0) {
      // TODO: Replace with toast notification
      console.log('Please select content to reject.')
      return
    }
    
    this.submitBulkAction('/contents/bulk_reject', selectedIds)
  }

  private submitBulkAction(action: string, contentIds: string[]): void {
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = action
    
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    if (csrfToken) {
      const tokenInput = document.createElement('input')
      tokenInput.type = 'hidden'
      tokenInput.name = 'authenticity_token'
      tokenInput.value = csrfToken
      form.appendChild(tokenInput)
    }
    
    contentIds.forEach(id => {
      const input = document.createElement('input')
      input.type = 'hidden'
      input.name = 'content_ids[]'
      input.value = id
      form.appendChild(input)
    })
    
    document.body.appendChild(form)
    form.submit()
  }
}