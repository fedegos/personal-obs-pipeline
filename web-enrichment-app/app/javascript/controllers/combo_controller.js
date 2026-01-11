// app/javascript/controllers/combo_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  checkNew(event) {
    const value = event.target.value
    const options = Array.from(document.getElementById('categories-suggestions').options).map(o => o.value)
    
    if (value && !options.includes(value)) {
      // Estilo visual si es una categoría nueva para dar feedback al usuario
      event.target.style.borderColor = "#3b82f6" // Azul para "Nuevo"
    } else {
      event.target.style.borderColor = "#ccc"
    }
  }
}
