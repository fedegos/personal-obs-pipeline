import { Controller } from "@hotwired/stimulus"

// Envía el formulario de filtro por sentimiento al cambiar el select
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
