import { Controller } from "@hotwired/stimulus"

/**
 * Theme Controller
 *
 * Toggles dark/light theme and persists preference to localStorage
 * Defaults to system preference if no saved preference exists
 *
 * Usage:
 *   <div data-controller="theme" data-theme-storage-key-value="page-isdark">
 *     <button data-action="click->theme#toggle">
 *       <%= lucide_icon "sun", "data-theme-target": "lightIcon" %>
 *       <%= lucide_icon "moon", class: "hidden", "data-theme-target": "darkIcon" %>
 *     </button>
 *   </div>
 *
 * Targets:
 *   - lightIcon (required): Sun icon shown in light mode
 *   - darkIcon (required): Moon icon shown in dark mode
 *
 * Values:
 *   - storageKey (String, required): LocalStorage key for theme preference
 *     Example: "admin-isdark", "home-isdark"
 *
 * Actions:
 *   - toggle: Switch between dark and light theme
 */

// stimulus-validator: system-controller
export default class extends Controller<HTMLElement> {
  static targets = ["lightIcon", "darkIcon"]
  static values = { storageKey: String }

  declare readonly lightIconTarget: HTMLElement
  declare readonly darkIconTarget: HTMLElement
  declare readonly storageKeyValue: string

  connect(): void {
    this.initializeTheme()
  }

  toggle(): void {
    const isDark = document.documentElement.classList.contains('dark')
    const newIsDark = !isDark
    
    localStorage.setItem(this.storageKeyValue, JSON.stringify(newIsDark))
    this.updateTheme(newIsDark)
  }

  private initializeTheme(): void {
    const savedIsDark = this.getSavedTheme()
    this.updateTheme(savedIsDark)
  }

  private getSavedTheme(): boolean {
    // First check localStorage for saved preference
    const saved = localStorage.getItem(this.storageKeyValue)
    if (saved !== null) {
      return JSON.parse(saved)
    }
    
    // Default to dark mode if no saved preference (system default)
    return true
  }

  private updateTheme(isDark: boolean): void {
    if (isDark) {
      document.documentElement.classList.add('dark')
      this.lightIconTarget.classList.add('hidden')
      this.darkIconTarget.classList.remove('hidden')
    } else {
      document.documentElement.classList.remove('dark')
      this.lightIconTarget.classList.remove('hidden')
      this.darkIconTarget.classList.add('hidden')
    }
  }
}
