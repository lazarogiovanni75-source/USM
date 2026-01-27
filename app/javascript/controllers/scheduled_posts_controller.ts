import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static targets = [
    "postsList"
  ]

  static values = {
    roomId: String,
    userId: String
  }

  // Declare your targets and values
  declare readonly postsListTarget: HTMLElement
  declare readonly roomIdValue: string
  declare readonly userIdValue: string

  connect(): void {
    console.log("ScheduledPosts connected")
  }

  disconnect(): void {
    console.log("ScheduledPosts disconnected")
  }

  // View Management
  changeView(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLButtonElement
    const newView = target.dataset.view
    
    if (newView) {
      this.updateViewButtons(newView)
      // Use Turbo to navigate to new view
      const params = new URLSearchParams(window.location.search)
      params.set('view', newView)
      window.location.search = params.toString()
    }
  }

  updateViewButtons(activeView: string): void {
    document.querySelectorAll('[data-view]').forEach(btn => {
      btn.classList.remove('bg-primary-100', 'text-primary-700', 'dark:bg-primary-900/20', 'dark:text-primary-400')
      btn.classList.add('text-gray-600', 'hover:text-gray-900', 'dark:text-gray-400', 'dark:hover:text-white')
    })
    
    const activeBtn = document.querySelector(`[data-view="${activeView}"]`) as HTMLButtonElement
    if (activeBtn) {
      activeBtn.classList.remove('text-gray-600', 'hover:text-gray-900', 'dark:text-gray-400', 'dark:hover:text-white')
      activeBtn.classList.add('bg-primary-100', 'text-primary-700', 'dark:bg-primary-900/20', 'dark:text-primary-400')
    }
  }

  // Filtering
  filterByStatus(event: Event): void {
    const target = event.target as HTMLSelectElement
    const status = target.value
    this.filterPosts('status', status)
  }

  filterByPlatform(event: Event): void {
    const target = event.target as HTMLSelectElement
    const platform = target.value
    this.filterPosts('platform', platform)
  }

  filterPosts(filterType: string, filterValue: string): void {
    // Simple client-side filtering for demo
    const posts = document.querySelectorAll('[data-post-id]')
    
    posts.forEach(post => {
      const element = post as HTMLElement
      const postId = element.dataset.postId
      // In a real app, this would filter server-side
      element.style.display = 'block'
    })
  }

  // Post Actions
  publishNow(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLElement
    const actionEvent = new Event('click') as any
    actionEvent.target = target
    this.performAction(actionEvent)
  }

  deletePost(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLElement
    
    // Use custom modal instead of confirm()
    this.showConfirmationModal(
      'Delete Scheduled Post',
      'Are you sure you want to delete this scheduled post?',
      () => this.performAction(event)
    )
  }

  showConfirmationModal(title: string, message: string, onConfirm: () => void): void {
    // Use notification approach instead of confirm
    this.showNotification(`${title}: ${message}`, 'info')
    // In a real implementation, this would show a custom modal
    // For now, just proceed with the action
    onConfirm()
  }

  performAction(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLElement
    const postId = target.dataset.postId
    const action = target.dataset.action
    
    if (!postId || !action) {
      this.showNotification('Missing post ID or action', 'error')
      return
    }
    
    // Submit form using Turbo Stream pattern
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = `/scheduled_posts/${postId}/${action}`
    form.style.display = 'none'
    
    const csrfInput = document.createElement('input')
    csrfInput.type = 'hidden'
    csrfInput.name = 'authenticity_token'
    csrfInput.value = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
    form.appendChild(csrfInput)
    
    document.body.appendChild(form)
    form.submit()
    document.body.removeChild(form)
  }

  // Bulk Actions
  optimizeSchedule(event: Event): void {
    event.preventDefault()
    // Implementation for schedule optimization
    this.showNotification('Schedule optimization feature coming soon', 'info')
  }

  showEngagementPredictions(event: Event): void {
    event.preventDefault()
    // Implementation for engagement predictions
    this.showNotification('Engagement predictions feature coming soon', 'info')
  }

  batchSchedule(event: Event): void {
    event.preventDefault()
    window.location.href = '/drafts/bulk_schedule'
  }

  // Modal Actions
  closeBulkActions(event: Event): void {
    event.preventDefault()
    const modal = document.getElementById('bulk-actions-panel')
    if (modal) {
      modal.classList.add('hidden')
    }
  }

  toggleBulkActions(event: Event): void {
    event.preventDefault()
    const panel = document.getElementById('bulk-actions-panel')
    if (panel) {
      panel.classList.toggle('hidden')
    }
  }

  bulkPublish(event: Event): void {
    event.preventDefault()
    this.showNotification('Bulk publish feature coming soon', 'info')
    this.closeBulkActions(event)
  }

  bulkReschedule(event: Event): void {
    event.preventDefault()
    this.showNotification('Bulk reschedule feature coming soon', 'info')
    this.closeBulkActions(event)
  }

  bulkCancel(event: Event): void {
    event.preventDefault()
    this.showNotification('Bulk cancel feature coming soon', 'info')
    this.closeBulkActions(event)
  }

  bulkOptimize(event: Event): void {
    event.preventDefault()
    this.showNotification('Bulk optimize feature coming soon', 'info')
    this.closeBulkActions(event)
  }

  // Utility Methods
  refreshPosts(): void {
    window.location.reload()
  }

  showNotification(message: string, type: string = 'info'): void {
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 px-6 py-3 rounded-lg shadow-lg z-50 ${
      type === 'success' ? 'bg-green-500 text-white' :
        type === 'error' ? 'bg-red-500 text-white' :
          'bg-blue-500 text-white'
    }`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }

  // FORMS: Turbo + Turbo Streams handle everything automatically
  // - Forms submit via AJAX (Turbo Drive)
  // - Server responds with format.turbo_stream
  // - Turbo Streams update DOM automatically
  // - NO manual form handling needed in Stimulus
  //
  // Use Stimulus for:
  // - UI interactions (toggle, show/hide)
  // - Input validation/formatting
  // - Dynamic form fields
}
