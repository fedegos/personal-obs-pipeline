import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
export default class extends Controller {
  static targets = ["form"]

  connect() {
    // Verificamos que el controlador esté enganchado
    console.log("Search controller connected")
  }

  submit() {
    // Debounce: Evita disparar una petición por cada letra. 
    // Espera a que el usuario deje de escribir por 200ms.
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 200)
  }
}