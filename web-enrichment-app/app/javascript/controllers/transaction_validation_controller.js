import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["categoria", "sentimiento", "submit"]

  connect() {
    this.validate()
    ;[ "categoria", "sentimiento" ].forEach(name => {
      const el = this.element.querySelector(`[data-transaction-validation-target="${name}"]`)
      if (el) {
        el.addEventListener("change", this.boundValidate)
        el.addEventListener("input", this.boundValidate)
      }
    })
  }

  disconnect() {
    ;[ "categoria", "sentimiento" ].forEach(name => {
      const el = this.element.querySelector(`[data-transaction-validation-target="${name}"]`)
      if (el) {
        el.removeEventListener("change", this.boundValidate)
        el.removeEventListener("input", this.boundValidate)
      }
    })
  }

  get boundValidate() {
    return this._boundValidate || (this._boundValidate = () => this.validate())
  }

  validate() {
    const catEl = this.hasCategoriaTarget ? this.categoriaTarget : null
    const sentEl = this.hasSentimientoTarget ? this.sentimientoTarget : null
    const subEl = this.hasSubmitTarget ? this.submitTarget : null
    const cat = catEl?.value?.trim() ?? ""
    const sent = sentEl?.value?.trim() ?? ""
    const valid = cat.length > 0 && cat !== "Varios" && sent.length > 0

    if (catEl) catEl.classList.toggle("is-invalid", !cat || cat === "Varios")
    if (sentEl) sentEl.classList.toggle("is-invalid", !sent)
    if (subEl) subEl.disabled = !valid
  }
}
