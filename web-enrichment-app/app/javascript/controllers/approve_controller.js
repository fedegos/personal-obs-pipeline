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

  async onSubmit(e) {
    e.preventDefault()
    const form = this.formTarget
    const card = this.element.closest(".transaction-card")
    if (!card || !form) return

    const approveUrl = form.action
    const formData = new FormData(form)
    formData.append("authenticity_token", document.querySelector('[name="csrf-token"]')?.content || "")

    const cardHtml = card.outerHTML
    const grid = card.closest(".transactions-grid")
    const nextSibling = card.nextElementSibling

    card.classList.add("transaction-card-approving")
    this.showToast("Enviando…", "info")
    card.remove()

    try {
      const res = await fetch(approveUrl, {
        method: "PATCH",
        body: formData,
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest"
        },
        credentials: "same-origin"
      })

      if (res.ok) {
        const text = await res.text()
        if (text.trim().length > 0 && window.Turbo) {
          window.Turbo.renderStreamMessage(text)
        }
      } else {
        this.restoreCard(grid, nextSibling, cardHtml)
        const data = await res.json().catch(() => ({}))
        const msg = data.errors?.join?.(", ") || "No se pudo procesar la aprobación."
        this.showToast(msg, "error")
      }
    } catch (err) {
      this.restoreCard(grid, nextSibling, cardHtml)
      this.showToast("Error de red. Reintente.", "error")
    }
  }

  restoreCard(grid, nextSibling, cardHtml) {
    if (!grid) return
    const temp = document.createElement("div")
    temp.innerHTML = cardHtml
    const card = temp.firstElementChild
    if (card) {
      card.classList.remove("transaction-card-approving")
      if (nextSibling) {
        grid.insertBefore(card, nextSibling)
      } else {
        grid.appendChild(card)
      }
    }
  }

  showToast(message, type) {
    const container = document.getElementById("flash-container")
    if (!container) return
    const toast = document.createElement("div")
    toast.className = `toast-notification toast-${type}`
    toast.setAttribute("data-controller", "flash")
    toast.innerHTML = `
      <div class="toast-content">
        <span class="toast-icon">${type === "error" ? "✕" : type === "info" ? "ℹ" : "✓"}</span>
        <span class="toast-message">${message}</span>
      </div>
    `
    container.appendChild(toast)
  }
}
