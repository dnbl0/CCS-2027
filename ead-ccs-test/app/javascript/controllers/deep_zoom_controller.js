import { Controller } from "@hotwired/stimulus"

// Zoom and pan for the record page's large image (CCS-57): a "Zoom and pan" toggle that swaps the image for an OpenSeadragon
// viewer, with buttons to zoom in, zoom out and reset. The viewer code is imported on first use (deep_zoom_viewer.js), so a page
// view that never zooms downloads nothing extra. Without JavaScript the toggle never appears and the image stays as it is.
// A thumbnail that changes the large image (media_viewer.js) tells this controller, which opens the new image in the viewer.
export default class extends Controller {
  static targets = [ "toggle", "stage", "controls" ]
  static values = { sources: Array, label: String }

  connect() {
    this.viewer = null
    this.toggleTarget.hidden = false
    this.onFullscreen = () => this.viewer?.forceResize()
    document.addEventListener("fullscreenchange", this.onFullscreen)
  }

  disconnect() {
    document.removeEventListener("fullscreenchange", this.onFullscreen)
    this.destroy()
  }

  get image() { return this.element.closest("figure")?.querySelector("img.digital-assets__image") }
  get active() { return this.viewer !== null }

  toggle() { this.active ? this.close() : this.start() }

  async start() {
    this.toggleTarget.disabled = true
    try {
      this.tools = await import("controllers/deep_zoom_viewer")
      const source = this.sourceFor(this.image?.getAttribute("src"))
      this.viewer = await this.tools.createViewer(this.stageTarget, source, { label: this.image?.alt })
      this.element.classList.add("is-active")
      this.stageTarget.hidden = false
      this.controlsTarget.hidden = false
      this.toggleTarget.setAttribute("aria-pressed", "true")
      this.viewer.canvas.focus()
    } catch (_) {
      this.viewer = null // the viewer could not load: the plain image stays
      this.element.classList.remove("is-active")
    } finally {
      this.toggleTarget.disabled = false
    }
  }

  close() {
    this.destroy()
    this.element.classList.remove("is-active")
    this.stageTarget.hidden = true
    this.controlsTarget.hidden = true
    this.toggleTarget.setAttribute("aria-pressed", "false")
    this.toggleTarget.focus()
  }

  destroy() {
    this.viewer?.destroy()
    this.viewer = null
  }

  zoomIn() { this.tools.zoomIn(this.viewer) }
  zoomOut() { this.tools.zoomOut(this.viewer) }
  reset() { this.tools.reset(this.viewer) }

  // media-viewer:shown, from the thumbnails
  imageChanged(event) {
    if (!this.active) return
    const { src, alt } = event.detail
    this.tools.open(this.viewer, this.sourceFor(src), alt)
  }

  sourceFor(url) {
    return this.sourcesValue.find((source) => source.url === url) || { url, alt: this.labelValue }
  }
}
