import { Controller } from "@hotwired/stimulus"

// A record's media: the "Media metadata" panel (opened by the "Media information" button, closed by its own button or Esc, with
// focus going to the panel's close button and back to the opening button), full screen for the media section, and the
// thumbnails swapping the large image. Without JavaScript the panel stays closed, the thumbnails are links to
// the full-size images, and the full screen button never appears.
//
// The panel is always rendered (never [hidden]/display:none): it is an absolutely positioned child of the
// stage's flex layout, and toggling a flex child's display briefly counted it back into the stage's
// justify-content centring, jolting the large image. Opening and closing it only ever toggles the "is-open"
// class (transform/visibility, both paint-only) and aria-hidden, which never touches that layout.
export default class extends Controller {
  static targets = [ "stage", "image", "panel", "infoButton", "fullscreenButton", "fullscreenLabel", "counter", "previous", "next", "strip", "use" ]

  connect() {
    this.onKey = (event) => { if (event.key === "Escape" && this.isOpen) this.closePanel() }
    this.onFullscreen = () => this.syncFullscreen()
    this.element.addEventListener("keydown", this.onKey)
    document.addEventListener("fullscreenchange", this.onFullscreen)
    if (this.hasFullscreenButtonTarget && document.fullscreenEnabled) this.fullscreenButtonTarget.hidden = false
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.onKey)
    document.removeEventListener("fullscreenchange", this.onFullscreen)
  }

  get isOpen() {
    return this.hasPanelTarget && this.panelTarget.classList.contains("is-open")
  }

  togglePanel() {
    this.isOpen ? this.closePanel() : this.openPanel()
  }

  openPanel() {
    this.panelTarget.classList.add("is-open")
    this.panelTarget.removeAttribute("aria-hidden")
    this.infoButtonTarget.setAttribute("aria-expanded", "true")
    this.panelTarget.querySelector("button")?.focus()
  }

  closePanel() {
    this.panelTarget.classList.remove("is-open")
    this.panelTarget.setAttribute("aria-hidden", "true")
    this.infoButtonTarget.setAttribute("aria-expanded", "false")
    this.infoButtonTarget.focus()
  }

  async toggleFullscreen() {
    try {
      if (document.fullscreenElement) await document.exitFullscreen()
      else await this.element.requestFullscreen()
    } catch (_) { /* refused: the button does nothing */ }
  }

  syncFullscreen() {
    const on = document.fullscreenElement === this.element
    this.element.classList.toggle("is-fullscreen", on)
    if (this.hasFullscreenButtonTarget) {
      const button = this.fullscreenButtonTarget
      if (this.hasFullscreenLabelTarget) this.fullscreenLabelTarget.textContent = on ? button.dataset.labelOn : button.dataset.labelOff
      else if (button.dataset.labelOn) { // an icon-only button (the viewer layout): its name and tip change
        const label = on ? button.dataset.labelOn : button.dataset.labelOff
        button.setAttribute("aria-label", label)
        button.title = label
      }
    }
  }

  // Previous and next change the current image as a thumbnail does: one viewer, in sequence
  previous() { this.step(-1) }
  next() { this.step(1) }

  get thumbs() { return this.hasStripTarget ? [ ...this.stripTarget.querySelectorAll(".viewer-media__thumb") ] : [] }

  step(by) {
    const thumbs = this.thumbs
    const at = thumbs.findIndex((thumb) => thumb.classList.contains("is-current"))
    const target = thumbs[at + by]
    if (target) target.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))
  }

  // The arrows are disabled at the ends, "Use this image" follows the current image (an open record's download), and the strip keeps
  // the current thumbnail in view
  syncStrip(link) {
    const thumbs = this.thumbs
    const at = thumbs.indexOf(link)
    if (at < 0) return
    if (this.hasPreviousTarget) this.previousTarget.disabled = at === 0
    if (this.hasNextTarget) this.nextTarget.disabled = at === thumbs.length - 1
    if (this.hasUseTarget && link.dataset.mediaViewerLarge) this.useTarget.href = link.dataset.mediaViewerLarge
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    link.scrollIntoView({ block: "nearest", inline: "nearest", behavior: reduced ? "auto" : "smooth" })
  }

  // a thumbnail shows its large image in the band (a modified click still opens it in a new tab)
  show(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.button) return
    event.preventDefault()
    const link = event.currentTarget
    this.element.querySelectorAll(".digital-assets__other, .viewer-media__thumb").forEach((other) => {
      other.classList.toggle("is-current", other === link)
      if (other === link) other.setAttribute("aria-current", "true"); else other.removeAttribute("aria-current")
    })
    if (this.hasCounterTarget && link.dataset.mediaViewerCounter) this.counterTarget.textContent = link.dataset.mediaViewerCounter
    this.syncStrip(link)
    this.imageTarget.src = link.dataset.mediaViewerLarge
    this.imageTarget.alt = link.dataset.mediaViewerAlt
    this.dispatch("shown", { detail: { src: this.imageTarget.getAttribute("src"), alt: this.imageTarget.alt } }) // the zoom viewer follows
  }
}
