import { Controller } from "@hotwired/stimulus"

// Cierra el modal de reglas vaciando el contenedor
export default class extends Controller {
  close() {
    const container = document.getElementById("modal-container")
    if (container) container.innerHTML = ""
  }
}
