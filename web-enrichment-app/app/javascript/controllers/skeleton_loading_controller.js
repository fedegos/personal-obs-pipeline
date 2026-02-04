import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { count: { type: Number, default: 3 } }

  show(e) {
    const form = e?.target
    if (!form || form.tagName !== "FORM") return
    const turboFrame = form.getAttribute("data-turbo-frame")
    if (turboFrame !== "transactions_list") return
    const action = (form.action || "").toString()
    if (action.includes("approve_similar")) return

    const overlay = document.getElementById("skeleton-overlay")
    const template = document.getElementById("skeleton-cards-template")
    if (!overlay || !template) return

    const grid = overlay.querySelector(".skeleton-overlay-grid")
    if (!grid) return

    grid.replaceChildren()
    const fragment = document.createDocumentFragment()
    for (let i = 0; i < this.countValue; i++) {
      fragment.appendChild(template.content.cloneNode(true))
    }
    grid.appendChild(fragment)
    overlay.classList.add("is-visible")
  }

  hide(e) {
    if (e?.target?.id !== "transactions_list") return
    const overlay = document.getElementById("skeleton-overlay")
    if (!overlay) return
    overlay.classList.remove("is-visible")
    const grid = overlay.querySelector(".skeleton-overlay-grid")
    if (grid) grid.replaceChildren()
  }
}
