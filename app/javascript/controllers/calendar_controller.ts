import { Controller } from "@hotwired/stimulus"

// Simple Calendar Controller
export default class extends Controller<HTMLElement> {
  connect(): void {
    console.log('Calendar controller connected')
    this.initializeCalendar()
  }

  initializeCalendar(): void {
    this.setupEventListeners()
  }

  setupEventListeners(): void {
    // Keyboard navigation
    document.addEventListener('keydown', (e: KeyboardEvent) => {
      if (e.ctrlKey || e.metaKey) return
      
      switch(e.key) {
        case 'ArrowLeft':
          this.previousPeriod()
          break
        case 'ArrowRight':
          this.nextPeriod()
          break
        case 't':
        case 'T':
          this.goToToday()
          break
      }
    })
  }

  // View Management
  changeView(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLButtonElement
    const newView = target.dataset.view
    
    this.updateViewButtons(newView!)
    
    // Use Turbo to navigate to new view
    const params = new URLSearchParams(window.location.search)
    params.set('view', newView!)
    params.set('date', new Date().toISOString().split('T')[0])
    
    window.location.search = params.toString()
  }

  updateViewButtons(activeView: string): void {
    document.querySelectorAll('.calendar-view-btn').forEach(btn => {
      btn.classList.remove('bg-primary-100', 'text-primary-700', 'dark:bg-primary-900/20', 'dark:text-primary-400')
      btn.classList.add('text-gray-600', 'hover:text-gray-900', 'dark:text-gray-400', 'dark:hover:text-white')
    })
    
    const activeBtn = document.querySelector(`[data-view="${activeView}"]`) as HTMLButtonElement
    if (activeBtn) {
      activeBtn.classList.remove('text-gray-600', 'hover:text-gray-900', 'dark:text-gray-400', 'dark:hover:text-white')
      activeBtn.classList.add('bg-primary-100', 'text-primary-700', 'dark:bg-primary-900/20', 'dark:text-primary-400')
    }
  }

  // Navigation
  previousPeriod(event?: Event): void {
    if (event) event.preventDefault()
    this.navigatePeriod(-1)
  }

  nextPeriod(event?: Event): void {
    if (event) event.preventDefault()
    this.navigatePeriod(1)
  }

  navigatePeriod(direction: number): void {
    const urlParams = new URLSearchParams(window.location.search)
    const currentView = urlParams.get('view') || 'month'
    const currentDate = urlParams.get('date') || new Date().toISOString().split('T')[0]
    
    const date = new Date(currentDate)
    let newDate: Date
    
    switch(currentView) {
      case 'month':
        newDate = new Date(date.getFullYear(), date.getMonth() + direction, 1)
        break
      case 'week':
        newDate = new Date(date.getTime() + (direction * 7 * 24 * 60 * 60 * 1000))
        break
      case 'day':
        newDate = new Date(date.getTime() + (direction * 24 * 60 * 60 * 1000))
        break
      default:
        newDate = date
    }
    
    const params = new URLSearchParams(window.location.search)
    params.set('view', currentView)
    params.set('date', newDate.toISOString().split('T')[0])
    
    window.location.search = params.toString()
  }

  goToToday(event?: Event): void {
    if (event) event.preventDefault()
    
    const today = new Date()
    const params = new URLSearchParams(window.location.search)
    const currentView = params.get('view') || 'month'
    
    params.set('view', currentView)
    params.set('date', today.toISOString().split('T')[0])
    
    window.location.search = params.toString()
  }

  // Post Management
  showPostDetails(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLElement
    const postId = target.dataset.postId
    
    // Simple modal or redirect for now
    if (postId) {
      window.location.href = `/drafts/${postId}`
    }
  }

  editPost(event: Event): void {
    event.preventDefault()
    event.stopPropagation()
    const target = event.currentTarget as HTMLElement
    const postId = target.dataset.postId
    
    if (postId) {
      window.location.href = `/drafts/${postId}/edit`
    }
  }

  deletePost(event: Event): void {
    event.preventDefault()
    event.stopPropagation()
    
    // Use notification approach instead of confirm
    this.showNotification('Are you sure you want to delete this scheduled post?', 'info')
    // In a real implementation, this would show a custom modal
    // For now, just proceed with the action
    this.performDelete(event)
  }

  performDelete(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLElement
    const postId = target.dataset.postId
    
    if (!postId) {
      this.showNotification('Post ID not found', 'error')
      return
    }
    
    // Submit form using Turbo Stream pattern
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = `/scheduled_posts/${postId}`
    form.style.display = 'none'
    
    const methodInput = document.createElement('input')
    methodInput.type = 'hidden'
    methodInput.name = '_method'
    methodInput.value = 'DELETE'
    form.appendChild(methodInput)
    
    const csrfInput = document.createElement('input')
    csrfInput.type = 'hidden'
    csrfInput.name = 'authenticity_token'
    csrfInput.value = (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content || ''
    form.appendChild(csrfInput)
    
    document.body.appendChild(form)
    form.submit()
    document.body.removeChild(form)
  }

  scheduleForDate(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLElement
    const date = target.dataset.date
    
    if (date) {
      window.location.href = `/drafts/new?date=${date}`
    }
  }

  scheduleForHour(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLElement
    const date = target.dataset.date
    const hour = target.dataset.hour
    
    if (date) {
      window.location.href = `/drafts/new?date=${date}&time=${hour}`
    }
  }

  newPost(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLElement
    const date = target.dataset.date
    
    if (date) {
      window.location.href = `/drafts/new?date=${date}`
    } else {
      window.location.href = '/drafts/new'
    }
  }

  // Quick Actions
  bulkSchedule(event: Event): void {
    event.preventDefault()
    window.location.href = '/drafts/bulk_schedule'
  }

  importContent(event: Event): void {
    event.preventDefault()
    window.location.href = '/drafts/import'
  }

  optimizeSchedule(event: Event): void {
    event.preventDefault()
    this.performOptimizeSchedule(event)
  }

  performOptimizeSchedule(event: Event): void {
    event.preventDefault()
    
    // Submit form using Turbo Stream pattern
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = '/calendar/optimize'
    form.style.display = 'none'
    
    const csrfInput = document.createElement('input')
    csrfInput.type = 'hidden'
    csrfInput.name = 'authenticity_token'
    csrfInput.value = (document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement)?.content || ''
    form.appendChild(csrfInput)
    
    document.body.appendChild(form)
    form.submit()
    document.body.removeChild(form)
  }

  refreshOptimalTimes(event?: Event): void {
    if (event) event.preventDefault()
    this.performOptimizeSchedule(event || new Event('click'))
  }

  fillGap(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLElement
    const date = target.dataset.gapDate
    
    if (date) {
      window.location.href = `/drafts/new?date=${date}`
    }
  }

  showMorePosts(event: Event): void {
    event.preventDefault()
    const target = event.currentTarget as HTMLElement
    const date = target.dataset.date
    
    if (date) {
      const params = new URLSearchParams(window.location.search)
      params.set('view', 'day')
      params.set('date', date)
      
      window.location.search = params.toString()
    }
  }

  // Modal Management
  closeModal(event?: Event): void {
    if (event) event.preventDefault()
    const modal = document.getElementById('quick-schedule-modal')
    if (modal) {
      modal.classList.add('hidden')
    }
  }

  // Utility Methods
  refreshCalendar(): void {
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
}