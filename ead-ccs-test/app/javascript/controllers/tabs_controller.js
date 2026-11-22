import { Controller } from "@hotwired/stimulus"

// Tabs (WAI-ARIA tabs pattern, automatic activation), as the design system's tabs (the record page's "You may be interested in"): one tab in the tab
// order (roving tabindex); Left and Right move between tabs and show each one's panel, Home and End go to the first and the last.
// A panel's lazy Turbo frame loads only once its panel is shown. Without JavaScript every panel is shown, one under the other.
export default class extends Controller {
  static targets = [ "tab", "panel" ]

  connect() {
    this.element.classList.add("is-tabbed")
    this.select(Math.max(this.tabTargets.findIndex((tab) => tab.getAttribute("aria-selected") === "true"), 0), { focus: false })
  }

  choose(event) { this.select(this.tabTargets.indexOf(event.currentTarget), { focus: false }) }

  keydown(event) {
    const count = this.tabTargets.length
    const index = this.tabTargets.indexOf(event.currentTarget)
    const next = { ArrowRight: (index + 1) % count, ArrowLeft: (index - 1 + count) % count, Home: 0, End: count - 1 }[event.key]
    if (next === undefined) return
    event.preventDefault()
    this.select(next, { focus: true })
  }

  select(index, { focus }) {
    this.tabTargets.forEach((tab, position) => {
      const selected = position === index
      tab.setAttribute("aria-selected", String(selected))
      tab.tabIndex = selected ? 0 : -1
      this.panelTargets[position].hidden = !selected
    })
    if (focus) this.tabTargets[index].focus()
  }
}
