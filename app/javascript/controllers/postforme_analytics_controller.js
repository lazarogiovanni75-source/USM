import { Controller } from "@hotwired/stimulus"

// Stimulus controller for Postforme Analytics Dashboard
// Handles chart interactions and analytics-specific behaviors
export default class extends Controller {
  static targets = ["chartContainer"]

  connect() {
    // Initialize any chart libraries or animations
  }

  // Calculate score color based on performance score
  scoreColor(score) {
    if (score >= 80) return 'from-green-500 to-green-600';
    if (score >= 60) return 'from-blue-500 to-blue-600';
    if (score >= 40) return 'from-amber-500 to-amber-600';
    return 'from-gray-400 to-gray-500';
  }

  // Format large numbers with K/M suffixes
  formatNumber(num) {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M';
    }
    if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
  }

  // Export analytics data as CSV
  exportData(event) {
    event.preventDefault();
    
    const posts = window.analyticsData || [];
    if (posts.length === 0) {
      alert('No data to export');
      return;
    }

    const headers = ['Title', 'Platform', 'Posted At', 'Likes', 'Comments', 'Shares', 'Impressions', 'Engagement Rate', 'Score'];
    const rows = posts.map(post => [
      post.title,
      post.platform,
      post.posted_at,
      post.metrics.likes,
      post.metrics.comments,
      post.metrics.shares,
      post.metrics.impressions,
      post.metrics.engagement_rate + '%',
      post.performance_score
    ]);

    const csv = [headers, ...rows].map(row => row.join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = `analytics_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  // Filter posts by platform
  filterPlatform(platform) {
    const url = new URL(window.location);
    if (platform && platform !== 'all') {
      url.searchParams.set('platform', platform);
    } else {
      url.searchParams.delete('platform');
    }
    window.location.href = url.toString();
  }

  // Change time period
  changePeriod(days) {
    const url = new URL(window.location);
    url.searchParams.set('days', days);
    window.location.href = url.toString();
  }

  // Refresh analytics data
  refreshAnalytics(event) {
    if (event) event.preventDefault();
    
    const button = event?.currentTarget;
    if (button) {
      button.disabled = true;
      button.innerHTML = '<span class="animate-spin inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full mr-2"></span> Refreshing...';
    }

    fetch('/postforme_analytics/refresh', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.notice) {
        // Show success toast or message
        window.location.reload();
      }
    })
    .catch(error => {
      console.error('Refresh failed:', error);
      if (button) {
        button.disabled = false;
        button.innerHTML = '<svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path></svg> Refresh';
      }
    });
  }
}
