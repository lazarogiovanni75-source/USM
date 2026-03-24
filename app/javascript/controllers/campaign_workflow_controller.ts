import { Controller } from "@hotwired/stimulus"

export default class CampaignWorkflowController extends Controller<HTMLElement> {
  static targets = [
    "prompt",
    "generateImage",
    "generateVideo",
    "postNow",
    "scheduleOptions",
    "scheduledAt"
  ]

  declare readonly promptTarget: HTMLTextAreaElement
  declare readonly generateImageTarget: HTMLInputElement
  declare readonly generateVideoTarget: HTMLInputElement
  declare readonly postNowTarget: HTMLInputElement
  declare readonly scheduleOptionsTarget: HTMLElement
  declare readonly scheduledAtTarget: HTMLInputElement

  connect(): void {
    console.log("CampaignWorkflow connected")
  }

  disconnect(): void {
    console.log("CampaignWorkflow disconnected")
  }

  // Toggle schedule options based on post_now checkbox
  toggleScheduleOptions(): void {
    const postNow = this.element.querySelector('[data-campaign-workflow-target="postNow"]') as HTMLInputElement | null
    const scheduleOptions = this.element.querySelector('[data-campaign-workflow-target="scheduleOptions"]') as HTMLElement | null
    
    if (postNow && scheduleOptions) {
      if (postNow.checked) {
        scheduleOptions.classList.add('hidden')
      } else {
        scheduleOptions.classList.remove('hidden')
      }
    }
  }
}
