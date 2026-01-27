/**
 * Mobile WebView Optimization Controller
 * 
 * Handles mobile-specific optimizations and WebView compatibility
 */

import { Controller } from "@hotwired/stimulus"

interface MobileInfo {
  isMobile: boolean
  isWebView: boolean
  platform: string
  version?: string
  capabilities: string[]
}

/**
 * Mobile and WebView detection and optimization
 */
export default class extends Controller {
  declare readonly hasInstallButtonTarget: boolean
  declare readonly installButtonTarget: HTMLElement
  
  // Stimulus targets
  static targets = ["installButton", "mobileActions", "touchAreas"]
  
  // Mobile info cache
  private cachedMobileInfo: MobileInfo | null = null
  private isInitialized = false
  private performanceObserver?: PerformanceObserver
  private cleanupInstallPrompt?: () => void

  connect() {
    this.initializeMobileOptimization()
    this.setupTouchOptimizations()
    this.setupPerformanceOptimizations()
    this.handleWebViewSpecifics()
    this.setupOfflineHandling()
    
    this.isInitialized = true
    console.log('Mobile optimization: Initialized')
  }

  disconnect() {
    this.cleanup()
  }

  /**
   * Initialize mobile optimization features
   */
  private async initializeMobileOptimization() {
    // Detect mobile platform
    this.cachedMobileInfo = this.detectMobile()
    
    // Apply mobile-specific optimizations
    this.applyMobileOptimizations()
    
    // Setup PWA install prompt for mobile
    this.setupPWAInstall()
    
    // Handle mobile navigation
    this.optimizeMobileNavigation()
    
    // Setup mobile-specific event listeners
    this.setupMobileEventListeners()
  }

  /**
   * Detect mobile platform and capabilities
   */
  private detectMobile(): MobileInfo {
    const userAgent = navigator.userAgent.toLowerCase()
    const isMobile = /android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(userAgent)
    const isWebView = this.detectWebView()
    const platform = this.getPlatform(userAgent)
    
    return {
      isMobile,
      isWebView,
      platform,
      capabilities: this.getCapabilities(userAgent, isWebView)
    }
  }

  /**
   * Detect WebView environment
   */
  private detectWebView(): boolean {
    const userAgent = navigator.userAgent.toLowerCase()
    
    // Common WebView patterns
    const webViewPatterns = [
      /wv/i,
      /webview/i,
      /instagram/i,
      /fbav/i,
      /fban/i,
      /twitter/i,
      /android.*wv/i,
      /iphone.*wv/i,
      /ipad.*wv/i
    ]
    
    return webViewPatterns.some(pattern => pattern.test(userAgent))
  }

  /**
   * Get platform information
   */
  private getPlatform(userAgent: string): string {
    if (/android/i.test(userAgent)) return 'android'
    if (/iphone|ipad|ipod/i.test(userAgent)) return 'ios'
    if (/windows phone/i.test(userAgent)) return 'windows'
    return 'desktop'
  }

  /**
   * Get platform capabilities
   */
  private getCapabilities(userAgent: string, isWebView: boolean): string[] {
    const capabilities: string[] = []
    
    // Check for PWA capabilities
    if ('serviceWorker' in navigator) capabilities.push('service_worker')
    if ('caches' in window) capabilities.push('caching')
    if ('Notification' in window) capabilities.push('notifications')
    
    // Check for mobile-specific capabilities
    if ('geolocation' in navigator) capabilities.push('geolocation')
    if ('mediaDevices' in navigator) capabilities.push('camera_microphone')
    if ('vibrate' in navigator) capabilities.push('vibration')
    
    // WebView-specific capabilities
    if (isWebView) {
      capabilities.push('webview')
      if (userAgent.includes('instagram')) capabilities.push('instagram_webview')
      if (userAgent.includes('facebook')) capabilities.push('facebook_webview')
      if (userAgent.includes('twitter')) capabilities.push('twitter_webview')
    }
    
    return capabilities
  }

  /**
   * Apply mobile-specific CSS optimizations
   */
  private applyMobileOptimizations() {
    if (!this.cachedMobileInfo?.isMobile) return
    
    document.documentElement.classList.add('mobile-device')
    
    if (this.cachedMobileInfo.isWebView) {
      document.documentElement.classList.add('webview-environment')
    }
    
    // Add platform-specific classes
    document.documentElement.classList.add(`platform-${this.cachedMobileInfo.platform}`)
    
    // Optimize for touch
    document.documentElement.classList.add('touch-optimized')
    
    // Apply viewport meta tag if not present
    this.ensureViewportMeta()
    
    // Optimize scrolling
    this.optimizeScrolling()
  }

  /**
   * Setup PWA install prompt for mobile
   */
  private setupPWAInstall() {
    if (!this.cachedMobileInfo?.isMobile) return
    
    // Check if PWA is already installed
    if (this.isStandalone()) {
      this.hideInstallButton()
      return
    }
    
    // Setup beforeinstallprompt event
    this.setupInstallPrompt()
  }

  /**
   * Setup install prompt event listener
   */
  private setupInstallPrompt() {
    const handleBeforeInstallPrompt = (e: Event) => {
      e.preventDefault()
      this.showInstallButton()
      
      // Store the event for later use
      ;(window as any).deferredPrompt = e
    }
    
    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
    
    // Store cleanup function
    this.cleanupInstallPrompt = () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
    }
  }

  /**
   * Setup touch optimizations
   */
  private setupTouchOptimizations() {
    if (!this.cachedMobileInfo?.isMobile) return
    
    // Optimize touch events
    this.setupTouchEventOptimization()
    
    // Setup swipe gestures
    this.setupSwipeGestures()
    
    // Optimize tap events
    this.setupTapOptimization()
  }

  /**
   * Setup performance optimizations
   */
  private setupPerformanceOptimizations() {
    // Monitor performance
    this.setupPerformanceMonitoring()
    
    // Optimize image loading
    this.setupImageOptimization()
  }

  /**
   * Handle WebView-specific behaviors
   */
  private handleWebViewSpecifics() {
    if (!this.cachedMobileInfo?.isWebView) return
    
    // Handle navigation within WebView
    this.handleWebViewNavigation()
    
    // Handle sharing capabilities
    this.setupWebViewSharing()
  }

  /**
   * Setup offline handling
   */
  private setupOfflineHandling() {
    window.addEventListener('online', this.handleOnline.bind(this))
    window.addEventListener('offline', this.handleOffline.bind(this))
    
    // Show offline indicator if needed
    this.updateConnectionStatus()
  }

  /**
   * Optimize mobile navigation
   */
  private optimizeMobileNavigation() {
    // Add mobile-specific navigation optimizations
    this.addMobileNavigationClasses()
    
    // Optimize navigation for touch
    this.optimizeNavigationTouch()
  }

  /**
   * Setup mobile event listeners
   */
  private setupMobileEventListeners() {
    // Handle orientation changes
    window.addEventListener('orientationchange', this.handleOrientationChange.bind(this))
    
    // Handle visibility changes
    document.addEventListener('visibilitychange', this.handleVisibilityChange.bind(this))
  }

  // Event Handlers

  /**
   * Handle online event
   */
  private handleOnline() {
    console.log('Mobile: Back online')
    this.showConnectionStatus('online')
    this.syncOfflineData()
  }

  /**
   * Handle offline event
   */
  private handleOffline() {
    console.log('Mobile: Gone offline')
    this.showConnectionStatus('offline')
    this.queueOfflineActions()
  }

  /**
   * Handle orientation change
   */
  private handleOrientationChange() {
    // Force reflow after orientation change
    setTimeout(() => {
      window.dispatchEvent(new Event('resize'))
    }, 100)
  }

  /**
   * Handle visibility change
   */
  private handleVisibilityChange() {
    if (document.hidden) {
      this.handlePageHidden()
    } else {
      this.handlePageVisible()
    }
  }

  /**
   * Handle page hidden
   */
  private handlePageHidden() {
    // Pause any ongoing activities
    console.log('Mobile: Page hidden')
  }

  /**
   * Handle page visible
   */
  private handlePageVisible() {
    // Resume activities
    console.log('Mobile: Page visible')
  }

  // Mobile Optimization Methods

  /**
   * Ensure viewport meta tag is present
   */
  private ensureViewportMeta() {
    let viewport = document.querySelector('meta[name="viewport"]')
    
    if (!viewport) {
      viewport = document.createElement('meta')
      viewport.setAttribute('name', 'viewport')
      document.head.appendChild(viewport)
    }
    
    viewport.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no')
  }

  /**
   * Optimize scrolling for mobile
   */
  private optimizeScrolling() {
    // Add smooth scrolling class
    document.documentElement.classList.add('smooth-scroll')
    
    // Prevent overscroll on iOS
    if (this.cachedMobileInfo?.platform === 'ios') {
      document.body.style.overscrollBehavior = 'none'
    }
  }

  /**
   * Setup touch event optimization
   */
  private setupTouchEventOptimization() {
    // Prevent default touch behaviors that might interfere
    document.addEventListener('touchstart', (e) => {
      // Don't prevent if it's a form input
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
        return
      }
    }, { passive: true })
  }

  /**
   * Setup swipe gestures
   */
  private setupSwipeGestures() {
    let startX = 0
    let startY = 0
    let endX = 0
    let endY = 0

    document.addEventListener('touchstart', (e: any) => {
      startX = e.touches[0].clientX
      startY = e.touches[0].clientY
    }, { passive: true })

    document.addEventListener('touchend', (e: any) => {
      endX = e.changedTouches[0].clientX
      endY = e.changedTouches[0].clientY
      
      const deltaX = endX - startX
      const deltaY = endY - startY
      const minSwipeDistance = 50

      if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > minSwipeDistance) {
        if (deltaX > 0) {
          this.dispatch('swipeRight', { detail: { deltaX, deltaY } })
        } else {
          this.dispatch('swipeLeft', { detail: { deltaX, deltaY } })
        }
      } else if (Math.abs(deltaY) > minSwipeDistance) {
        if (deltaY > 0) {
          this.dispatch('swipeDown', { detail: { deltaX, deltaY } })
        } else {
          this.dispatch('swipeUp', { detail: { deltaX, deltaY } })
        }
      }
    }, { passive: true })
  }

  /**
   * Setup tap optimization to prevent double-tap zoom
   */
  private setupTapOptimization() {
    let lastTouchEnd = 0
    
    document.addEventListener('touchend', (e: any) => {
      const now = new Date().getTime()
      if (now - lastTouchEnd <= 300) {
        e.preventDefault()
      }
      lastTouchEnd = now
    }, false)
  }

  /**
   * Setup performance monitoring
   */
  private setupPerformanceMonitoring() {
    if ('PerformanceObserver' in window) {
      this.performanceObserver = new PerformanceObserver((list) => {
        const entries = list.getEntries()
        entries.forEach((entry) => {
          if (entry.entryType === 'navigation') {
            this.recordNavigationMetrics(entry as any)
          } else if (entry.entryType === 'paint') {
            this.recordPaintMetrics(entry as any)
          }
        })
      })
      
      this.performanceObserver.observe({ entryTypes: ['navigation', 'paint', 'largest-contentful-paint'] })
    }
  }

  /**
   * Setup image optimization for mobile
   */
  private setupImageOptimization() {
    // Lazy load images
    if ('IntersectionObserver' in window) {
      const imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const img = entry.target as HTMLImageElement
            if (img.dataset.src) {
              img.src = img.dataset.src
              img.removeAttribute('data-src')
              imageObserver.unobserve(img)
            }
          }
        })
      })
      
      document.querySelectorAll('img[data-src]').forEach(img => {
        imageObserver.observe(img)
      })
    }
  }

  /**
   * Handle WebView navigation
   */
  private handleWebViewNavigation() {
    if (this.cachedMobileInfo?.platform === 'android') {
      console.log('Mobile: Android WebView detected')
    } else if (this.cachedMobileInfo?.platform === 'ios') {
      console.log('Mobile: iOS WebView detected')
    }
  }

  /**
   * Setup WebView sharing capabilities
   */
  private setupWebViewSharing() {
    if (typeof navigator.share !== 'undefined') {
      document.documentElement.classList.add('web-share-api')
    }
  }

  // Utility Methods

  /**
   * Check if app is running standalone (PWA installed)
   */
  private isStandalone(): boolean {
    return window.matchMedia('(display-mode: standalone)').matches ||
           (navigator as any).standalone === true ||
           document.referrer.includes('android-app://')
  }

  /**
   * Show install button
   */
  private showInstallButton() {
    if (this.hasInstallButtonTarget) {
      this.installButtonTarget?.classList.remove('hidden')
    }
  }

  /**
   * Hide install button
   */
  private hideInstallButton() {
    if (this.hasInstallButtonTarget) {
      this.installButtonTarget?.classList.add('hidden')
    }
  }

  /**
   * Add mobile navigation classes
   */
  private addMobileNavigationClasses() {
    document.documentElement.classList.add('mobile-navigation')
  }

  /**
   * Optimize navigation for touch
   */
  private optimizeNavigationTouch() {
    // Add touch-friendly navigation classes
    const navElements = document.querySelectorAll('nav a, .nav a, [role="navigation"] a')
    navElements.forEach(el => {
      el.classList.add('touch-friendly')
    })
  }

  /**
   * Update connection status
   */
  private updateConnectionStatus() {
    const isOnline = navigator.onLine
    this.showConnectionStatus(isOnline ? 'online' : 'offline')
  }

  /**
   * Show connection status
   */
  private showConnectionStatus(status: 'online' | 'offline') {
    // Dispatch event for other components to handle
    this.dispatch('connectionStatusChanged', { detail: { status } })
  }

  /**
   * Sync offline data
   */
  private syncOfflineData() {
    // Sync any data that was queued while offline
    console.log('Mobile: Syncing offline data')
  }

  /**
   * Queue offline actions
   */
  private queueOfflineActions() {
    // Queue actions for when back online
    console.log('Mobile: Queueing offline actions')
  }

  /**
   * Record navigation metrics
   */
  private recordNavigationMetrics(entry: any) {
    console.log('Navigation timing:', entry)
  }

  /**
   * Record paint metrics
   */
  private recordPaintMetrics(entry: any) {
    console.log('Paint timing:', entry)
  }

  /**
   * Cleanup
   */
  private cleanup() {
    if (this.performanceObserver) {
      this.performanceObserver.disconnect()
    }
    
    if (this.cleanupInstallPrompt) {
      this.cleanupInstallPrompt()
    }
    
    this.isInitialized = false
  }
}