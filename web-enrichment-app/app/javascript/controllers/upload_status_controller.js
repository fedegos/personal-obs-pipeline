import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "status"]

  connect() {
    this.reset()
  }

  submit() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
    if (this.hasStatusTarget) {
      this.statusTarget.style.display = "inline"
      this.statusTarget.textContent = "Subiendo..."
    }
  }

  reset() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
    if (this.hasStatusTarget) this.statusTarget.style.display = "none"
  }
}
