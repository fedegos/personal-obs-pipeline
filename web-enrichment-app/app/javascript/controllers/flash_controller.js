// app/javascript/controllers/flash_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Desvanecer después de 3 segundos
    setTimeout(() => {
      this.element.style.opacity = '0'
      // Eliminar del DOM después de la animación
      setTimeout(() => { this.element.remove() }, 500)
    }, 3000)
  }
}
