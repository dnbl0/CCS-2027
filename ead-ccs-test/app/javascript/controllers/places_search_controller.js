import { Controller } from "@hotwired/stimulus"

// The Places page's search (browse/places): the results follow the search as it is typed (after a short pause), in the results frame,
// with the address kept (data-turbo-action="advance"), so the search box keeps its focus. When the frame changes (a search, a region, a
// letter, a view) the page announces what it now shows and the search keeps the chosen region. Without JavaScript the form submits.
export default class extends Controller {
  static targets = [ "form", "input", "region", "status", "frame" ]
  static DELAY = 300

  connect() {
    this.loaded = () => {
      const state = this.frameTarget.querySelector("[data-places-state]")
      if (!state) return
      this.statusTarget.textContent = state.dataset.summary || ""
      this.regionTarget.value = state.dataset.region || ""
      this.regionTarget.disabled = !this.regionTarget.value // no empty region= in the address
    }
    this.frameTarget.addEventListener("turbo:frame-load", this.loaded)
  }

  disconnect() {
    clearTimeout(this.timer)
    this.frameTarget.removeEventListener("turbo:frame-load", this.loaded)
  }

  type() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.formTarget.requestSubmit(), this.constructor.DELAY)
  }
}
