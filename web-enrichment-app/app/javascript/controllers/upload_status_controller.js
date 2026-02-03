import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "status"]

  submit() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
    if (this.hasStatusTarget) {
      this.statusTarget.style.display = "inline"
      this.statusTarget.textContent = "Subiendo..."
    }
  }
}
