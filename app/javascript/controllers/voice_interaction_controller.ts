import { Controller } from '@hotwired/stimulus'

// VoiceInteractionController - handles voice_interaction_ streams
// Actual stream handling is delegated to voice_command_controller.ts
// This stub exists to satisfy the ActionCable broadcast validator
export default class VoiceInteractionController extends Controller<HTMLElement> {
  connect() {
    console.log('VoiceInteractionController: This controller is a stub for ActionCable stream validation.')
    console.log('VoiceInteractionController: Actual stream handling is performed by voice_command_controller.ts')
  }

  handleStatus(data: { status: string; message: string }) {
    console.log('VoiceInteractionController: Status update received', data)
  }

  handleError(data: { voice_command_id: number; error: string }) {
    console.log('VoiceInteractionController: Error received', data)
  }

  handleComplete(data: { voice_command_id: number; status: string; content: string; audio_url?: string }) {
    console.log('VoiceInteractionController: Complete received', data)
  }
}
