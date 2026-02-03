import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    debounce: { type: Number, default: 500 }
  }

  static targets = ["form", "status"]

  connect() {
    this.timeout = null
    this.boundSave = this.save.bind(this)
  }

  change() {
    if (this.timeout) clearTimeout(this.timeout)
    this.timeout = setTimeout(this.boundSave, this.debounceValue)
  }

  async save() {
    this.timeout = null
    if (!this.formTarget || !this.urlValue) return

    this.setStatus("guardando")
    const formData = new FormData(this.formTarget)
    formData.append("authenticity_token", document.querySelector('[name="csrf-token"]')?.content || "")

    try {
      const res = await fetch(this.urlValue, {
        method: "PATCH",
        body: formData,
        headers: {
          "X-Requested-With": "XMLHttpRequest",
          "Accept": "application/json"
        },
        credentials: "same-origin"
      })
      const data = await res.json().catch(() => ({}))
      if (res.ok && data.ok) {
        this.setStatus("guardado")
      } else {
        this.setStatus("error")
      }
    } catch {
      this.setStatus("error")
    }
  }

  useSuggestion(event) {
    event.preventDefault()
    const btn = event.currentTarget
    if (!this.formTarget || !this.urlValue) return

    const categoria = btn.dataset.categoria || ""
    const subCategoria = btn.dataset.subCategoria || ""
    const sentimiento = btn.dataset.sentimiento || ""

    const formData = new FormData()
    formData.append("transaction[categoria]", categoria)
    formData.append("transaction[sub_categoria]", subCategoria)
    formData.append("transaction[sentimiento]", sentimiento)
    formData.append("use_suggestion", "1")
    formData.append("authenticity_token", document.querySelector('[name="csrf-token"]')?.content || "")

    this.setStatus("guardando")
    fetch(this.urlValue, {
      method: "PATCH",
      body: formData,
      headers: {
        "X-Requested-With": "XMLHttpRequest",
        "Accept": "application/json"
      },
      credentials: "same-origin"
    })
      .then(r => r.json())
      .then((data) => {
        if (data.ok) {
          this.setStatus("guardado")
          window.location.reload()
        } else {
          this.setStatus("error")
        }
      })
      .catch(() => this.setStatus("error"))
  }

  setStatus(state) {
    if (!this.hasStatusTarget) return
    const el = this.statusTarget
    el.textContent = { guardando: "Guardando…", guardado: "Guardado ✓", error: "Error al guardar" }[state] || ""
    el.className = "auto-save-status auto-save-" + state
  }
}
