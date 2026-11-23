import { Controller } from "@hotwired/stimulus"

// Places on the home page (NexusCcs::PlacePreviewComponent): the places are tabs, each showing its spotlight. A click chooses a place;
// the arrow keys move between them (and choose), Home and End go to the first and last. Without JavaScript the tab row stays hidden and
// every spotlight shows, one after another.
export default class extends Controller {
  static targets = [ "list", "tab", "panel" ]

  connect() {
    this.listTarget.hidden = false
    this.show(Math.max(0, this.tabTargets.findIndex((tab) => tab.getAttribute("aria-selected") === "true")))
  }

  select(event) { this.show(this.tabTargets.indexOf(event.currentTarget)) }

  key(event) {
    const index = this.tabTargets.indexOf(event.currentTarget)
    const last = this.tabTargets.length - 1
    const next = { ArrowRight: index + 1, ArrowDown: index + 1, ArrowLeft: index - 1, ArrowUp: index - 1, Home: 0, End: last }[event.key]
    if (next === undefined) return
    event.preventDefault()
    const target = next < 0 ? last : next > last ? 0 : next
    this.show(target)
    this.tabTargets[target].focus()
  }

  show(index) {
    this.tabTargets.forEach((tab, i) => {
      tab.setAttribute("aria-selected", i === index ? "true" : "false")
      tab.tabIndex = i === index ? 0 : -1
    })
    this.panelTargets.forEach((panel, i) => { panel.hidden = i !== index })
  }
}
