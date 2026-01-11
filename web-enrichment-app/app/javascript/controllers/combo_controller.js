import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "subInput"]

  connect() {
    // Si el input ya trae un valor de la DB, actualizamos el mapa de sugerencias
    if (this.inputTarget.value) {
      this.updateSuggestions()
    }
  }

  checkNew() {
    // Cuando el usuario escribe, limpiamos el campo de subcategoría
    // porque la categoría principal cambió.
    this.subInputTarget.value = ""
    this.updateSuggestions()
  }

  updateSuggestions() {
    const value = this.inputTarget.value
    const categoriesData = document.getElementById('categories-data')
    if (!categoriesData) return

    const categoriesMap = JSON.parse(categoriesData.dataset.map)
    const subDatalist = document.getElementById('subcategories-suggestions')
    
    // Limpiar sugerencias previas
    subDatalist.innerHTML = ""

    if (categoriesMap[value]) {
      categoriesMap[value].forEach(sub => {
        const option = document.createElement('option')
        option.value = sub
        subDatalist.appendChild(option)
      })
      this.inputTarget.style.borderColor = "#38a169" // Verde si existe
    } else {
      this.inputTarget.style.borderColor = "#3b82f6" // Azul si es nueva
    }
  }
}
