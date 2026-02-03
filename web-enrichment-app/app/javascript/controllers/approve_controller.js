import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  connect() {
    if (this.hasFormTarget) {
      this.formTarget.addEventListener("submit", this.boundSubmit)
    }
  }

  disconnect() {
    if (this.hasFormTarget) {
      this.formTarget.removeEventListener("submit", this.boundSubmit)
    }
  }

  get boundSubmit() {
    if (!this._boundSubmit) this._boundSubmit = this.onSubmit.bind(this)
    return this._boundSubmit
  }

  onSubmit() {
    const card = this.element.closest(".transaction-card")
    if (card) card.classList.add("transaction-card-approving")
  }
}
