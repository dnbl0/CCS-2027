import { Controller } from "@hotwired/stimulus"

// A record's media (DigitalAssetsComponent, the left of the record page): the round tools under the picture and the thumbnail strip.
// Zoom in and zoom out are passed to the zoom viewer (deep_zoom_controller listens for media-viewer:zoom), which opens on the first
// zoom in; full screen is for the media section; a thumbnail swaps the large image and is marked as the one on show, and previous
// and next step through the thumbnails. Without JavaScript the tools and steps never appear and each thumbnail of an open image is
// a link to its full size.
export default class extends Controller {
  static targets = [ "stage", "image", "thumb", "step", "tool", "fullscreenButton", "fullscreenLabel" ]

  connect() {
    this.onFullscreen = () => this.syncFullscreen()
    document.addEventListener("fullscreenchange", this.onFullscreen)
    this.toolTargets.forEach((tool) => { tool.hidden = false })
    this.stepTargets.forEach((step) => { step.hidden = false })
    if (this.hasFullscreenButtonTarget && document.fullscreenEnabled) this.fullscreenButtonTarget.hidden = false
  }

  disconnect() {
    document.removeEventListener("fullscreenchange", this.onFullscreen)
  }

  zoomIn() { this.dispatch("zoom", { detail: { direction: "in" } }) }
  zoomOut() { this.dispatch("zoom", { detail: { direction: "out" } }) }

  async toggleFullscreen() {
    try {
      if (document.fullscreenElement) await document.exitFullscreen()
      else await this.element.requestFullscreen()
    } catch (_) { /* refused: the button does nothing */ }
  }

  syncFullscreen() {
    const on = document.fullscreenElement === this.element
    this.element.classList.toggle("is-fullscreen", on)
    if (this.hasFullscreenButtonTarget && this.hasFullscreenLabelTarget) {
      const button = this.fullscreenButtonTarget
      this.fullscreenLabelTarget.textContent = on ? button.dataset.labelOn : button.dataset.labelOff
    }
  }

  // a thumbnail shows its large image on the stage (a modified click still opens it in a new tab)
  show(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.button) return
    event.preventDefault()
    this.display(event.currentTarget)
  }

  previous() { this.step(-1) }
  next() { this.step(1) }

  step(offset) {
    const thumbs = this.thumbTargets
    if (thumbs.length === 0) return
    const current = Math.max(thumbs.findIndex((thumb) => thumb.getAttribute("aria-current") === "true"), 0)
    const target = thumbs[(current + offset + thumbs.length) % thumbs.length]
    this.display(target)
    target.scrollIntoView({ block: "nearest", inline: "nearest" })
  }

  display(thumb) {
    // the first image's size attributes would hold the next one to its shape: let the new image take its own
    this.imageTarget.removeAttribute("width")
    this.imageTarget.removeAttribute("height")
    this.imageTarget.closest("figure")?.classList.remove("digital-assets__main--sized")
    this.imageTarget.src = thumb.dataset.mediaViewerLarge
    this.imageTarget.alt = thumb.dataset.mediaViewerAlt
    this.thumbTargets.forEach((other) => { if (other === thumb) other.setAttribute("aria-current", "true"); else other.removeAttribute("aria-current") })
    this.dispatch("shown", { detail: { src: this.imageTarget.getAttribute("src"), alt: this.imageTarget.alt } }) // the zoom viewer follows
  }
}
