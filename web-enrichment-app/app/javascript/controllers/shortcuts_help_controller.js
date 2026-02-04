import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "trigger"]

  connect() {
    this.boundKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  onKeydown(e) {
    if (e.key === "?" && !this.isTyping(e.target)) {
      e.preventDefault()
      this.toggle()
    }
    if (e.key === "Escape" && this.isOpen()) {
      e.preventDefault()
      this.close()
    }
  }

  open() {
    const modal = this.modalTarget
    modal.classList.add("shortcuts-help-modal--open")
    modal.setAttribute("aria-hidden", "false")
    this.triggerTarget?.setAttribute("aria-expanded", "true")
  }

  close() {
    const modal = this.modalTarget
    modal.classList.remove("shortcuts-help-modal--open")
    modal.setAttribute("aria-hidden", "true")
    this.triggerTarget?.setAttribute("aria-expanded", "false")
  }

  toggle() {
    if (this.isOpen()) this.close()
    else this.open()
  }

  isOpen() {
    return this.modalTarget?.classList.contains("shortcuts-help-modal--open")
  }

  isTyping(el) {
    if (!el) return false
    const tag = el.tagName?.toLowerCase()
    const role = el.getAttribute?.("role")
    return tag === "input" || tag === "textarea" || role === "textbox" || el.isContentEditable
  }
}
