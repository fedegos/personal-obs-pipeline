import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  onKeydown(e) {
    if (!this.element.contains(document.activeElement)) return

    if (e.key === "Escape") {
      if (document.activeElement && typeof document.activeElement.blur === "function") {
        document.activeElement.blur()
      }
      return
    }

    if (e.key === "Enter" && (e.ctrlKey || !e.target.matches("textarea"))) {
      const form = document.activeElement?.closest("form.transaction-approval-form")
      if (form && form.querySelector('button[type="submit"]')) {
        e.preventDefault()
        form.requestSubmit()
      }
    }
  }
}
