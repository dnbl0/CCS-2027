import { Controller } from "@hotwired/stimulus"

// The record page's "More from the collections" tabs (MoreFromCollectionsComponent): ARIA tabs (the WAI-ARIA Authoring Practices
// tabs pattern, automatic activation). Without JavaScript the tab list stays hidden and every panel is shown under its own heading;
// with it, one panel shows at a time and the headings are left to the tabs. Each panel's lazy frame loads when the panel is first
// shown (lazy_frame_controller.js says when a panel has nothing to show).
export default class extends Controller {
  static targets = [ "list", "tab", "panel", "panelHeading" ]

  connect() {
    this.listTarget.hidden = false
    this.panelHeadingTargets.forEach((heading) => { heading.hidden = true })
    this.panelTargets.forEach((panel) => panel.setAttribute("role", "tabpanel"))
    this.show(this.tabTargets.findIndex((tab) => tab.getAttribute("aria-selected") === "true"), false)
  }

  select(event) {
    this.show(this.tabTargets.indexOf(event.currentTarget), false)
  }

  key(event) {
    const last = this.tabTargets.length - 1
    const current = this.tabTargets.indexOf(event.currentTarget)
    const next = { ArrowRight: current === last ? 0 : current + 1, ArrowLeft: current === 0 ? last : current - 1, Home: 0, End: last }[event.key]
    if (next === undefined) return
    event.preventDefault()
    this.show(next, true)
  }

  show(index, focus) {
    const chosen = Math.max(index, 0)
    this.tabTargets.forEach((tab, position) => {
      const selected = position === chosen
      tab.setAttribute("aria-selected", String(selected))
      tab.tabIndex = selected ? 0 : -1
      this.panelTargets[position].hidden = !selected
    })
    if (focus) this.tabTargets[chosen].focus()
  }
}
