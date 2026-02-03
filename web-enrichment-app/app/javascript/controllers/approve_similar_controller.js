import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    categoria: String,
    subCategoria: String,
    sentimiento: String,
    url: String
  }

  confirm() {
    const count = this.element.dataset.approveSimilarCount || "?"
    const cat = this.categoriaValue
    const msg = `¿Aprobar todas las transacciones con categoría ${cat}?`
    if (!confirm(msg)) return

    const formData = new FormData()
    formData.append("categoria", this.categoriaValue)
    formData.append("sub_categoria", this.subCategoriaValue || "")
    formData.append("sentimiento", this.sentimientoValue)
    formData.append("authenticity_token", document.querySelector('[name="csrf-token"]')?.content || "")

    fetch(this.urlValue, {
      method: "PATCH",
      body: formData,
      headers: { "X-Requested-With": "XMLHttpRequest" },
      credentials: "same-origin"
    })
      .then(() => { window.location.reload() })
      .catch(() => alert("Error al aprobar."))
  }
}
