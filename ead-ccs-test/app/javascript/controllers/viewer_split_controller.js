import { Controller } from "@hotwired/stimulus"

// The split screen of the record page's viewer layout (?layout=viewer): the data panel on the left, the viewer on the right.
// From 1024px a round toggle on the dividing line collapses and expands the panel (the choice is remembered in sessionStorage as a
// convenience only; the panel's contents leave the tab order and the accessibility tree while it is collapsed, and focus stays on the
// toggle). Below 1024px the two are two views, "Show images" and "Show data", chosen by two buttons: only the chosen one is shown.
// Without JavaScript nothing is hidden. The viewer is told to resize whenever the stage changes size (viewer-split:resized).
export default class extends Controller {
  static targets = [ "panel", "stage", "toggle", "switch", "imagesButton", "dataButton", "print", "sections", "bar" ]
  static values = { collapsed: Boolean, single: Boolean, view: { type: String, default: "images" } }

  connect() {
    this.wide = window.matchMedia("(min-width: 64rem)")
    try { if (window.sessionStorage.getItem("viewerPanelCollapsed") === "1") this.collapsedValue = true } catch (_) { /* no storage: the default */ }
    this.onChange = () => this.apply()
    this.wide.addEventListener("change", this.onChange)
    if (this.hasSwitchTarget) this.switchTarget.hidden = false
    if (this.hasPrintTarget) this.printTarget.hidden = false
    if (this.hasToggleTarget) this.toggleTarget.hidden = false
    this.apply()
  }

  disconnect() {
    this.wide.removeEventListener("change", this.onChange)
  }

  toggle() {
    this.collapsedValue = !this.collapsedValue
    try { window.sessionStorage.setItem("viewerPanelCollapsed", this.collapsedValue ? "1" : "0") } catch (_) { /* no storage */ }
    this.apply()
    this.toggleTarget.focus()
  }

  showImages() { this.viewValue = "images"; this.apply() }
  showData() { this.viewValue = "data"; this.apply() }

  // "Use this image" for a view-only record: its terms are in Rights and access, in the panel. Open the panel first if it is closed.
  showRights(event) {
    this.collapsedValue = false
    this.viewValue = "data"
    this.apply()
    const target = document.getElementById("viewer-rights")
    if (!target) return
    event.preventDefault()
    requestAnimationFrame(() => {
      target.scrollIntoView({ block: "start" })
      target.focus({ preventScroll: true })
    })
  }

  print() { window.print() }

  apply() {
    const wide = this.wide.matches
    if (this.singleValue) return // no media: the panel is the page, there is nothing to switch
    // wide: the panel is hidden when collapsed. Narrow: the title always shows, the rest of the data and the bar only in the data view,
    // and the viewer only in the images view
    this.panelTarget.hidden = wide && this.collapsedValue
    const dataHidden = !wide && this.viewValue !== "data"
    if (this.hasSectionsTarget) this.sectionsTarget.hidden = dataHidden
    if (this.hasBarTarget) this.barTarget.hidden = dataHidden
    this.stageTarget.hidden = wide ? false : this.viewValue !== "images"
    this.element.querySelector(".viewer-app")?.classList.toggle("is-collapsed", wide && this.collapsedValue)
    if (this.hasToggleTarget) {
      const open = !this.collapsedValue
      this.toggleTarget.setAttribute("aria-expanded", String(open))
      this.toggleTarget.setAttribute("aria-label", open ? this.toggleTarget.dataset.labelOpen : this.toggleTarget.dataset.labelClosed)
      this.toggleTarget.title = this.toggleTarget.getAttribute("aria-label")
    }
    if (this.hasImagesButtonTarget) {
      this.imagesButtonTarget.setAttribute("aria-pressed", String(this.viewValue === "images"))
      this.dataButtonTarget.setAttribute("aria-pressed", String(this.viewValue === "data"))
    }
    window.dispatchEvent(new CustomEvent("viewer-split:resized"))
  }
}
