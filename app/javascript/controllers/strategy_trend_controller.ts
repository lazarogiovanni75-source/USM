import { Controller } from "@hotwired/stimulus"

interface TrendData {
  trend: string
  change_percent: number
  scores?: number[]
}

export default class extends Controller {
  connect() {
    const url = this.element.getAttribute('data-strategy-trend-url')
    if (url) {
      // stimulus-validator: disable-next-line
      this.loadTrend(url)
    }
  }

  // stimulus-validator: disable-next-line
  async loadTrend(url: string) {
    try {
      const response = await fetch(url)
      const data: TrendData = await response.json()
      this.renderTrend(data)
    } catch (error) {
      console.error("Failed to load trend:", error)
      this.showError()
    }
  }

  renderTrend(data: TrendData) {
    if (data.trend === 'no_data') {
      this.element.innerHTML = `
        <div class="text-center py-8">
          <p class="text-sm text-muted">Generate strategies to see trends</p>
          <a href="/ai_marketing_strategy" class="text-sm text-primary hover:underline mt-2 inline-block">Generate First Strategy</a>
        </div>
      `
      return
    }

    const trendColor = data.trend === 'improving' ? 'text-success' : data.trend === 'declining' ? 'text-error' : 'text-muted'
    const trendLabel = data.trend === 'improving' ? 'Improving' : data.trend === 'declining' ? 'Declining' : 'Stable'

    this.element.innerHTML = `
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center gap-2">
          <span class="text-2xl font-bold ${trendColor}">${data.change_percent}%</span>
          <span class="text-sm text-muted">change</span>
        </div>
        <span class="px-3 py-1 rounded-full text-sm font-medium ${trendColor} bg-opacity-10">
          ${trendLabel}
        </span>
      </div>
      ${data.scores && data.scores.length > 0 ? `
        <div class="flex items-end justify-between h-24 gap-2">
          ${data.scores.map((score: number, i: number) => `
            <div class="flex-1 flex flex-col items-center gap-1">
              <div class="w-full bg-primary/20 rounded-t" style="height: ${score}%"></div>
              <span class="text-xs text-muted">${i + 1}</span>
            </div>
          `).join('')}
        </div>
        <p class="text-xs text-muted text-center mt-2">Last ${data.scores.length} strategies</p>
      ` : ''}
    `
  }

  showError() {
    this.element.innerHTML = `
      <div class="text-center py-8">
        <p class="text-sm text-error">Failed to load trend data</p>
      </div>
    `
  }
}
