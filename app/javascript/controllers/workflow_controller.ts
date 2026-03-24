import { BaseChannelController } from "./base_channel_controller"
import consumer from "../channels/consumer"

/**
 * WorkflowController - Handles workflow status updates via ActionCable
 */
export default class extends BaseChannelController {
  connect() {
    super.connect()
    this.createWorkflowSubscription()
  }

  private createWorkflowSubscription() {
    if (this.subscription) return

    const workflowId = (this.element as HTMLElement & { dataset: { workflowId: string } }).dataset.workflowId
    if (!workflowId) return

    this.subscription = consumer.subscriptions.create(
      { channel: 'WorkflowChannel', workflow_id: workflowId },
      {
        connected: () => {
          console.log('[Workflow] Connected to workflow channel')
        },
        disconnected: () => {
          console.log('[Workflow] Disconnected from workflow channel')
        },
        received: (data: { type: string; message?: string; status?: string }) => {
          this.handleWorkflowUpdate(data)
        }
      }
    )
  }

  protected channelReceived(data: any): void {
    this.handleWorkflowUpdate(data)
  }

  protected handleWorkflowStarted(data: { message?: string }): void {
    this.updateStatus('running', data.message || 'Workflow is running...')
  }

  protected handleWorkflowCompleted(data: { message?: string }): void {
    this.updateStatus('completed', data.message || 'Workflow completed.')
  }

  protected handleWorkflowFailed(data: { message?: string }): void {
    this.updateStatus('failed', data.message || 'Workflow failed.')
  }

  private handleWorkflowUpdate(data: { type: string; message?: string; status?: string }) {
    if (data.type === 'workflow_started') {
      this.handleWorkflowStarted(data)
    } else if (data.type === 'workflow_completed') {
      this.handleWorkflowCompleted(data)
    } else if (data.type === 'workflow_failed') {
      this.handleWorkflowFailed(data)
    }
  }

  private updateStatus(status: string, message?: string) {
    const badge = document.getElementById('workflow-status-badge')
    const dot = document.getElementById('workflow-status-dot')
    const text = document.getElementById('workflow-status-text')
    const detail = document.getElementById('workflow-status-detail')
    const banner = document.getElementById('workflow-live-banner')
    const bannerMsg = document.getElementById('workflow-live-message')

    const label = status.charAt(0).toUpperCase() + status.slice(1)
    if (text) text.textContent = label
    if (detail) detail.textContent = label
    if (bannerMsg && message) bannerMsg.textContent = message

    const colorMap: Record<string, { badge: string; dot: string }> = {
      running: { badge: 'bg-blue-100 text-blue-700', dot: 'bg-blue-400 animate-pulse' },
      completed: { badge: 'bg-green-100 text-green-700', dot: 'bg-green-400' },
      failed: { badge: 'bg-red-100 text-red-700', dot: 'bg-red-400' }
    }
    const colors = colorMap[status] || { badge: 'bg-gray-100 text-gray-700', dot: 'bg-gray-400' }

    if (badge) badge.className = `inline-flex items-center px-3 py-1.5 rounded-full text-sm font-medium ${colors.badge}`
    if (dot) dot.className = `w-2 h-2 rounded-full mr-2 ${colors.dot}`
    if (banner) banner.classList.toggle('hidden', status !== 'running')

    if (status === 'completed' || status === 'failed') {
      setTimeout(() => { window.location.reload() }, 1500)
    }
  }
}
