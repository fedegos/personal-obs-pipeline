import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { count: { type: Number, default: 3 } }

  show(e) {
    const url = e?.detail?.fetchOptions?.url ?? ""
    if (url && !url.includes("transactions")) return
    const frame = document.getElementById("transactions_list")
    if (!frame || frame.querySelector(".skeleton-transaction-card")) return
    const card = '<div class="skeleton-transaction-card"><div class="skeleton-card-header"><div class="skeleton-line skeleton-id"></div><div class="skeleton-line skeleton-amount"></div></div><div class="skeleton-card-body"><div class="skeleton-line skeleton-details"></div><div class="skeleton-line skeleton-date"></div></div><div class="skeleton-card-footer"><div class="skeleton-line skeleton-form"></div></div></div>'
    const html = Array(this.countValue).fill(card).join("")
    frame.innerHTML = `<div class="transactions-grid" id="transactions-container">${html}</div>`
  }
}
