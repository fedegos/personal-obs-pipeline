import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    // console.log("Combo controller conectado") // Verifica esto en la consola (F12)
  }

  checkNew() {
    const value = this.inputTarget.value
    const datalist = document.getElementById('categories-suggestions')
    
    // Convertimos las opciones del datalist a un array de strings
    const options = Array.from(datalist.options).map(opt => opt.value)

    if (value.length === 0) {
      this.inputTarget.style.borderColor = "#cbd5e0" // Color base
    } else if (options.includes(value)) {
      this.inputTarget.style.borderColor = "#38a169" // Verde: Ya existe
    } else {
      this.inputTarget.style.borderColor = "#3b82f6" // Azul: Nuevo
    }
  }
}
