// app/javascript/controllers/parameters_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bankSelect", "schemaContainer", "fieldTemplate", "fileInput", "fileLabel"]
  static values = { 
    schemas: Object,
    noFileBanks: Array 
  }

  connect() {
    this.showSchema()
  }

  showSchema() {
    const bank = this.bankSelectTarget.value
    const schema = this.schemasValue[bank]
    const fieldsDiv = this.schemaContainerTarget.querySelector("#dynamic-fields")

    // 1. Gestionar si el banco requiere archivo o no
    this.toggleFileInput(bank)

    // 2. Limpiar y generar campos dinámicos
    fieldsDiv.innerHTML = "" 

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

  toggleFileInput(bank) {
    // Si el banco no está seleccionado o está en la lista de "no file"
    const isNoFileBank = this.noFileBanksValue.includes(bank)
    
    if (bank && isNoFileBank) {
      this.fileInputTarget.value =""
      this.fileInputTarget.disabled = true
      this.fileInputTarget.style.opacity = "0.4"
      this.fileInputTarget.style.cursor = "not-allowed"
      this.fileLabelTarget.style.opacity = "0.4"
      this.fileLabelTarget.innerText = "Archivo (No requerido para Google Sheets)"
    } else {
      this.fileInputTarget.disabled = false
      this.fileInputTarget.style.opacity = "1"
      this.fileInputTarget.style.cursor = "default"
      this.fileLabelTarget.style.opacity = "1"
      this.fileLabelTarget.innerText = "Archivo (Excel/CSV)"
    }
  }

  createFieldFromTemplate(field) {
    const clone = this.fieldTemplateTarget.content.cloneNode(true)
    const label = clone.querySelector("label")
    const input = clone.querySelector("input")

    label.textContent = field.label
    input.type = field.type || "text"
    input.name = `extra_params[${field.key}]`
    
    if (field.default !== undefined) {
      field.type === "checkbox" ? (input.checked = field.default) : (input.value = field.default)
    }

    if (field.placeholder) input.placeholder = field.placeholder

    if (field.type === "checkbox") {
      const group = clone.querySelector(".field-group")
      group.style.flexDirection = "row-reverse"
      group.style.justifyContent = "flex-end"
      group.style.gap = "10px"
    }

    return clone
  }
}
