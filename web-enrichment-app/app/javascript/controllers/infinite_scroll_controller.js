import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Connects to data-controller="infinite-scroll"
export default class extends Controller {
  static targets = ["sentinel", "button", "status"]
  static values = {
    nextUrl: String
  }

  connect() {
    this.loading = false
    this.observeSentinel()
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }

  loadMore(event) {
    if (event) event.preventDefault()
    this.fetchNextPage()
  }

  observeSentinel() {
    if (!this.hasSentinelTarget || !this.hasNextUrlValue) return

    this.observer = new IntersectionObserver((entries) => {
      const firstEntry = entries[0]
      if (firstEntry?.isIntersecting) this.fetchNextPage()
    }, { rootMargin: "250px 0px" })

    this.observer.observe(this.sentinelTarget)
  }

  async fetchNextPage() {
    if (this.loading || !this.hasNextUrlValue) return

    this.loading = true
    this.setLoadingState(true)

    try {
      const response = await fetch(this.nextUrlValue, {
        method: "GET",
        credentials: "same-origin",
        headers: { Accept: "text/vnd.turbo-stream.html" }
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const stream = await response.text()
      Turbo.renderStreamMessage(stream)
    } catch (_error) {
      if (this.hasStatusTarget) this.statusTarget.textContent = "Error al cargar más."
    } finally {
      this.loading = false
      this.setLoadingState(false)
    }
  }

  setLoadingState(isLoading) {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = isLoading
      this.buttonTarget.hidden = isLoading
    }
    if (this.hasStatusTarget) this.statusTarget.textContent = isLoading ? "Cargando..." : ""
  }
}
