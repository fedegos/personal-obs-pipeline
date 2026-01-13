import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bankSelect", "schemaContainer", "fieldTemplate"]
  static values = { schemas: Object }

  showSchema() {
    const bank = this.bankSelectTarget.value
    const schema = this.schemasValue[bank]
    const fieldsDiv = this.schemaContainerTarget.querySelector("#dynamic-fields")

    fieldsDiv.innerHTML = "" // Limpiar

    if (schema && schema.length > 0) {
      this.schemaContainerTarget.style.display = "block"
      schema.forEach(field => {
        const clone = this.createFieldFromTemplate(field)
        fieldsDiv.appendChild(clone)
      })
    } else {
      this.schemaContainerTarget.style.display = "none"
    }
  }

  createFieldFromTemplate(field) {
    // 1. Clonar el contenido del template
    const clone = this.fieldTemplateTarget.content.cloneNode(true)
    
    // 2. Buscar elementos internos
    const label = clone.querySelector("label")
    const input = clone.querySelector("input")

    // 3. Configurar datos
    label.textContent = field.label
    input.type = field.type || "text"
    input.name = `extra_params[${field.key}]`
    
    if (field.default !== undefined) {
      field.type === "checkbox" ? (input.checked = field.default) : (input.value = field.default)
    }

    if (field.placeholder) input.placeholder = field.placeholder

    // 4. Ajuste visual rápido si es checkbox
    if (field.type === "checkbox") {
      clone.querySelector(".field-group").style.flexDirection = "row-reverse"
      clone.querySelector(".field-group").style.justifyContent = "flex-end"
      clone.querySelector(".field-group").style.gap = "10px"
    }

    return clone
  }
}
