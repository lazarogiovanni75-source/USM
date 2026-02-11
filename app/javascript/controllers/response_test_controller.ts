// Response Test Controller - For testing the voice response window
// Used to dispatch voice:response events for debugging
import { Controller } from "@hotwired/stimulus"

export default class ResponseTestController extends Controller {
  connect(): void {
    console.log("ResponseTest controller connected")
  }

  dispatchTestResponse(): void {
    const event = new CustomEvent("voice:response", {
      detail: { text: "Test response from debug button!", type: "success" }
    })
    window.dispatchEvent(event)
    console.log("Test voice:response event dispatched")
  }
}
