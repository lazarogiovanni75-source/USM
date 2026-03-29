import { Controller } from "@hotwired/stimulus"

export default class extends Controller<HTMLElement> {
  static targets = [
    "form",
    "examples",
    "exampleInput",
    "document",
    "submitBtn"
  ]

  declare readonly formTarget: HTMLElement
  declare readonly examplesTarget: HTMLElement
  declare readonly exampleInputTarget: HTMLTextAreaElement
  declare readonly documentTarget: HTMLTextAreaElement
  declare readonly submitBtnTarget: HTMLButtonElement

  connect(): void {
    console.log("BrandVoice controller connected")
  }

  addExample(): void {
    const textarea = document.createElement("textarea")
    textarea.className = "example-input form-input w-full mt-3"
    textarea.rows = 3
    textarea.placeholder = "Paste an example post here..."
    this.examplesTarget.appendChild(textarea)
  }

  selectOption(event: Event): void {
    const button = event.currentTarget as HTMLButtonElement
    const key = button.dataset.key
    const value = button.dataset.value

    // Remove selected state from siblings
    const siblings = button.parentElement?.querySelectorAll(".option-btn")
    siblings?.forEach((btn) => {
      btn.classList.remove("bg-purple-100", "dark:bg-purple-900", "border-purple-500", "dark:border-purple-400", "text-purple-700", "dark:text-purple-300")
      btn.classList.add("text-gray-700", "dark:text-gray-300")
    })

    // Add selected state
    button.classList.remove("text-gray-700", "dark:text-gray-300")
    button.classList.add("bg-purple-100", "dark:bg-purple-900", "border-purple-500", "dark:border-purple-400", "text-purple-700", "dark:text-purple-300")
  }

  prepareSubmit(): void {
    const submitBtn = this.submitBtnTarget
    submitBtn.disabled = true
    submitBtn.classList.add("opacity-50", "cursor-not-allowed")

    // Gather examples
    const examples: string[] = []
    this.examplesTarget.querySelectorAll("textarea").forEach((textarea) => {
      const value = textarea.value.trim()
      if (value) examples.push(value)
    })

    // Gather selected options
    const answers: Record<string, string> = {}
    this.formTarget.querySelectorAll(".option-btn").forEach((btn) => {
      const element = btn as HTMLButtonElement
      const key = element.dataset.key
      const value = element.dataset.value
      // Check if the button has the purple selected styling
      if (key && value && (btn.classList.contains("bg-purple-100") || btn.classList.contains("dark:bg-purple-900"))) {
        answers[key] = value
      }
    })

    // Populate hidden fields
    const examplesJsonField = document.getElementById("examples-json") as HTMLInputElement
    const answersJsonField = document.getElementById("answers-json") as HTMLInputElement
    const documentField = document.getElementById("document-input") as HTMLInputElement

    if (examplesJsonField) examplesJsonField.value = JSON.stringify(examples)
    if (answersJsonField) answersJsonField.value = JSON.stringify(answers)
    if (documentField) documentField.value = this.documentTarget.value.trim()

    // Submit the form - Turbo Drive will handle the rest
    const form = document.getElementById("brand-voice-generate-form") as HTMLFormElement
    if (form) form.submit()
  }

  showForm(): void {
    // Show the form section
    const formEl = document.getElementById("brand-voice-form")
    if (formEl) {
      formEl.classList.remove("hidden")
    }
  }
}
