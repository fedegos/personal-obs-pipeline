import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    categoria: String,
    subCategoria: String,
    sentimiento: String,
    previewUrl: String,
    url: String
  }

  async confirm() {
    const params = new URLSearchParams({
      categoria: this.categoriaValue || "",
      sub_categoria: this.subCategoriaValue || "",
      sentimiento: this.sentimientoValue || ""
    })

    const url = `${this.previewUrlValue}?${params}`

    let html
    try {
      const res = await fetch(url, {
        headers: { "X-Requested-With": "XMLHttpRequest" },
        credentials: "same-origin"
      })
      html = await res.text()
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
    } catch (e) {
      console.error("Preview fetch error:", e)
      alert("Error al obtener la vista previa.")
      return
    }

    if (!html || html.trim() === "") {
      alert("No hay transacciones que coincidan con esos criterios.")
      return
    }

    const container = document.getElementById("modal-container")
    if (!container) return

    container.innerHTML = html
    this._boundEscape = (e) => {
      if (e.key === "Escape") this.closeModal()
    }
    document.addEventListener("keydown", this._boundEscape)
  }

  closeModal() {
    const container = document.getElementById("modal-container")
    if (container) container.innerHTML = ""
    document.removeEventListener("keydown", this._boundEscape)
  }
}
