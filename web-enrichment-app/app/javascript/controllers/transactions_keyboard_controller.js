import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundKeydown = this.onKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  onKeydown(e) {
    if (!this.element.contains(document.activeElement)) return

    if (e.key === "Escape") {
      if (document.activeElement && typeof document.activeElement.blur === "function") {
        document.activeElement.blur()
      }
      return
    }

    if (e.key === "Enter" && (e.ctrlKey || !e.target.matches("textarea"))) {
      const form = document.activeElement?.closest("form.transaction-approval-form")
      if (form && form.querySelector('button[type="submit"]')) {
        e.preventDefault()
        form.requestSubmit()
      }
      return
    }

    const navKeys = [ "ArrowDown", "j", "ArrowUp", "k" ]
    if (navKeys.includes(e.key) && !this.isTyping(e.target)) {
      e.preventDefault()
      const dir = (e.key === "ArrowDown" || e.key === "j") ? 1 : -1
      this.focusAdjacentCard(dir)
    }
  }

  isTyping(el) {
    if (!el) return false
    const tag = el.tagName?.toLowerCase()
    return tag === "input" || tag === "textarea" || el.isContentEditable
  }

  focusAdjacentCard(dir) {
    const cards = Array.from(this.element.querySelectorAll(".transaction-card"))
    const currentCard = document.activeElement?.closest(".transaction-card")
    const idx = currentCard ? cards.indexOf(currentCard) : -1
    const nextIdx = idx + dir
    if (nextIdx < 0 || nextIdx >= cards.length) return
    const nextCard = cards[nextIdx]
    const focusable = nextCard.querySelector('select, input:not([type="hidden"]), button[type="submit"]')
    if (focusable) focusable.focus()
  }
}
