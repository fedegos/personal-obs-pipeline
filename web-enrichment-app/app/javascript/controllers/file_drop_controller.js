import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["zone", "input", "preview"]

  connect() {
    this.boundDragOver = this.onDragOver.bind(this)
    this.boundDragLeave = this.onDragLeave.bind(this)
    this.boundDrop = this.onDrop.bind(this)
    this.boundUpdate = () => this.updateFromInput()
    this.zoneTarget.addEventListener("dragover", this.boundDragOver)
    this.zoneTarget.addEventListener("dragleave", this.boundDragLeave)
    this.zoneTarget.addEventListener("drop", this.boundDrop)
    this.inputTarget.addEventListener("change", this.boundUpdate)
  }

  disconnect() {
    this.zoneTarget.removeEventListener("dragover", this.boundDragOver)
    this.zoneTarget.removeEventListener("dragleave", this.boundDragLeave)
    this.zoneTarget.removeEventListener("drop", this.boundDrop)
    this.inputTarget.removeEventListener("change", this.boundUpdate)
  }

  get dropZone() {
    return this.zoneTarget.querySelector(".file-drop-zone") || this.zoneTarget
  }

  onDragOver(e) {
    e.preventDefault()
    e.stopPropagation()
    this.dropZone.classList.add("file-drop-zone--active")
  }

  onDragLeave(e) {
    e.preventDefault()
    if (!this.zoneTarget.contains(e.relatedTarget)) {
      this.dropZone.classList.remove("file-drop-zone--active")
    }
  }

  onDrop(e) {
    e.preventDefault()
    e.stopPropagation()
    this.dropZone.classList.remove("file-drop-zone--active")
    const files = e.dataTransfer?.files
    if (files && files.length > 0 && this.inputTarget) {
      const dt = new DataTransfer()
      for (let i = 0; i < files.length; i++) dt.items.add(files[i])
      this.inputTarget.files = dt.files
      this.updatePreview(files[0])
    }
  }

  updateFromInput() {
    const file = this.inputTarget?.files?.[0]
    if (file) this.updatePreview(file)
    else this.clearPreview()
  }

  updatePreview(file) {
    if (!this.hasPreviewTarget) return
    const size = file.size < 1024 ? `${file.size} B` : file.size < 1024 * 1024 ? `${(file.size / 1024).toFixed(1)} KB` : `${(file.size / (1024 * 1024)).toFixed(2)} MB`
    const type = file.type || "Archivo"
    this.previewTarget.textContent = `${file.name} · ${size} · ${type}`
    this.previewTarget.style.display = "block"
  }

  clearPreview() {
    if (this.hasPreviewTarget) {
      this.previewTarget.textContent = ""
      this.previewTarget.style.display = "none"
    }
  }
}
