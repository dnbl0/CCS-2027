import { Controller } from "@hotwired/stimulus"

// Places on the home page (NexusCcs::PlacePreviewComponent): the place pointed at or focused is previewed beside the list, and marked
// as the current one. The preview is decorative (each place is its own link), so nothing is announced.
export default class extends Controller {
  static targets = ["row", "panel"]

  show(event) {
    const index = Number(event.currentTarget.dataset.index)
    this.rowTargets.forEach((row, i) => (i === index ? row.setAttribute("aria-current", "true") : row.removeAttribute("aria-current")))
    this.panelTargets.forEach((panel, i) => { panel.hidden = i !== index })
  }
}
