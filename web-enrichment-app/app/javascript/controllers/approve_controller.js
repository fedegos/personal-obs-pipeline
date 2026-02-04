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

    const grid = card.closest(".transactions-grid")
    const nextSibling = card.nextElementSibling
    const buffer = document.getElementById("cards-restore-buffer") || (() => {
      const b = document.createElement("div")
      b.id = "cards-restore-buffer"
      b.setAttribute("aria-hidden", "true")
      b.style.display = "none"
      document.body.appendChild(b)
      return b
    })()

    card.classList.add("transaction-card-approving")
    this.showToast("Enviando…", "info")
    buffer.appendChild(card)

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
        document.querySelectorAll("#flash-container [data-pending='true']").forEach((el) => el.remove())
        const text = await res.text()
        if (text.trim().length > 0 && window.Turbo) {
          window.Turbo.renderStreamMessage(text)
        }
      } else {
        this.restoreCard(grid, nextSibling, card)
        const data = await res.json().catch(() => ({}))
        const msg = data.errors?.join?.(", ") || "No se pudo procesar la aprobación."
        this.showToast(msg, "error")
      }
    } catch (err) {
      this.restoreCard(grid, nextSibling, card)
      this.showToast("Error de red. Reintente.", "error")
    }
  }

  restoreCard(grid, nextSibling, card) {
    if (!grid || !card) return
    card.classList.remove("transaction-card-approving")
    if (nextSibling) {
      grid.insertBefore(card, nextSibling)
    } else {
      grid.appendChild(card)
    }
  }

  showToast(message, type) {
    const container = document.getElementById("flash-container")
    const template = document.getElementById("toast-template")
    if (!container || !template) return
    const toast = template.content.cloneNode(true)
    const wrapper = toast.firstElementChild
    const iconEl = wrapper.querySelector(".toast-icon")
    const msgEl = wrapper.querySelector(".toast-message")
    const icons = { success: "✓", error: "✕", info: "ℹ" }
    wrapper.className = `toast-notification toast-${type}`
    if (type === "info") wrapper.setAttribute("data-pending", "true")
    if (iconEl) iconEl.textContent = icons[type] || icons.success
    if (msgEl) msgEl.textContent = message
    container.appendChild(toast)
  }
}
