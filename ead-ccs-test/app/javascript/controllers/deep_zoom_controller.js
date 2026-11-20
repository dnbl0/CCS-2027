import { Controller } from "@hotwired/stimulus"

// Zoom, pan and rotate for the record page's large image (CCS-57). The controls bar (media_viewer_controller sends
// media-viewer:zoom) swaps the image for an OpenSeadragon viewer on the first Zoom in or Rotate; Zoom out zooms back out, and at the
// whole, unrotated picture closes the viewer, so the plain image returns; Reset closes it at once. The viewer code is imported on first use (deep_zoom_viewer.js), so a page view
// that never zooms downloads nothing extra. Focus stays on the tool that was pressed. Without JavaScript the tools never appear.
// A thumbnail that changes the large image (media-viewer:shown) closes the viewer, so the new image starts whole and unrotated.
// After every change it reports deep-zoom:state for the controls.
export default class extends Controller {
  static targets = [ "stage" ]
  static values = { sources: Array, label: String }

  connect() {
    this.viewer = null
    this.onFullscreen = () => this.viewer?.forceResize()
    document.addEventListener("fullscreenchange", this.onFullscreen)
  }

  disconnect() {
    document.removeEventListener("fullscreenchange", this.onFullscreen)
    this.destroy()
  }

  get figure() { return this.element.closest("figure") }
  get image() { return this.figure?.querySelector("img.digital-assets__image") }
  get active() { return this.viewer !== null }

  // media-viewer:zoom, from the controls bar: { direction: "in" | "out" | "reset" | "rotate", degrees }
  async zoom(event) {
    const { direction, degrees } = event.detail
    if (direction === "reset") {
      if (this.active) this.close()
    } else if (direction === "rotate") {
      if (!this.active && !(await this.start())) return
      this.tools.rotate(this.viewer, degrees)
    } else if (direction === "in") {
      if (!this.active && !(await this.start())) return
      this.tools.zoomIn(this.viewer)
    } else if (this.active) {
      const { atHome, rotation } = this.tools.state(this.viewer)
      if (atHome && rotation === 0) this.close()
      else if (!atHome) this.tools.zoomOut(this.viewer)
    }
    this.report()
  }

  // Tells the media viewer where the view is (deep-zoom:state, bubbling to it), so its controls and readout follow; pinching,
  // double-clicking and the canvas keys move the view too, so the viewer's own events report as well
  report() {
    const detail = this.active ? { active: true, ...this.tools.state(this.viewer) } : { active: false, zoom: 100, atHome: true, atMax: false, rotation: 0 }
    this.dispatch("state", { detail })
  }

  async start() {
    if (this.starting) return false
    this.starting = true
    try {
      this.tools = await import("controllers/deep_zoom_viewer")
      // the viewer keeps the picture area's height, so opening it moves nothing below (media_viewer.css)
      this.figure?.style.setProperty("--zoom-height", `${Math.round(this.figure.getBoundingClientRect().height)}px`)
      const source = this.sourceFor(this.image?.getAttribute("src"))
      this.viewer = await this.tools.createViewer(this.stageTarget, source, { label: this.image?.alt })
      this.viewer.addHandler("animation-finish", () => this.report())
      this.viewer.addHandler("rotate", () => this.report())
      this.element.classList.add("is-active")
      this.stageTarget.hidden = false
      await this.tools.opened(this.viewer)
      return true
    } catch (_) {
      this.viewer = null // the viewer could not load: the plain image stays
      this.element.classList.remove("is-active")
      this.figure?.style.removeProperty("--zoom-height")
      return false
    } finally {
      this.starting = false
    }
  }

  close() {
    this.destroy()
    this.element.classList.remove("is-active")
    this.stageTarget.hidden = true
    this.figure?.style.removeProperty("--zoom-height")
  }

  destroy() {
    this.viewer?.destroy()
    this.viewer = null
  }

  // media-viewer:shown, from the thumbnails: another image starts at its whole picture, unrotated (the plain image returns)
  imageChanged() {
    if (!this.active) return
    this.close()
    this.report()
  }

  sourceFor(url) {
    return this.sourcesValue.find((source) => source.url === url) || { url, alt: this.labelValue }
  }
}
