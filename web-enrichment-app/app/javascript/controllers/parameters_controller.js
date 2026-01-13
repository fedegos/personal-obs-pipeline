// app/javascript/controllers/parameters_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bankSelect", "schemaContainer"]
  static values = { schemas: Object }

  connect() {
    console.log("Parameters controller connected. Schemas loaded:", this.schemasValue)
    this.showSchema()
  }

  showSchema() {
    const bank = this.bankSelectTarget.value
    const schema = this.schemasValue[bank]
    const container = this.schemaContainerTarget
    const fieldsDiv = container.querySelector("#dynamic-fields")

    console.log(`Showing schema for bank: ${bank}`, schema)

    if (schema && schema.length > 0) {
      container.style.display = "block"
      // Generamos el HTML completo para todos los campos
      fieldsDiv.innerHTML = schema.map(field => this.generateFieldHtml(field)).join("")
    } else {
      container.style.display = "none"
      fieldsDiv.innerHTML = ""
    }
  }

  generateFieldHtml(field) {
    const isCheckbox = field.type === 'checkbox'
    const valueAttr = field.default !== undefined && !isCheckbox ? `value="${field.default}"` : ""
    const placeholderAttr = field.placeholder ? `placeholder="${field.placeholder}"` : ""
    const checkedAttr = isCheckbox && field.default ? 'checked' : ''
    
    // HTML del input
    const inputHtml = `
      <input type="${field.type}" 
             name="extra_params[${field.key}]" 
             ${valueAttr} 
             ${placeholderAttr} 
             ${checkedAttr}
             style="${isCheckbox ? 'margin-top: 5px;' : 'width: 100%; padding: 8px; border: 1px solid #cbd5e1; border-radius: 4px; box-sizing: border-box;'}">
    `

    // Envolvemos en un div con label, ajustando layout para checkboxes
    if (isCheckbox) {
      return `
        <div style="display: flex; flex-direction: row; align-items: center; gap: 10px;">
          ${inputHtml}
          <label style="font-size: 0.85rem; font-weight: 600; color: #475569; cursor: pointer;">${field.label}</label>
        </div>`
    } else {
      return `
        <div style="display: flex; flex-direction: column; gap: 4px;">
          <label style="font-size: 0.75rem; font-weight: 700; color: #475569;">${field.label}</label>
          ${inputHtml}
        </div>
      `
    }
  }
}
