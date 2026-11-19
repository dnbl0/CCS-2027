import { Controller } from "@hotwired/stimulus"

// Zoom and pan for the record page's large image (CCS-57). The round Zoom in tool under the picture (media_viewer_controller sends
// media-viewer:zoom) swaps the image for an OpenSeadragon viewer and zooms in; Zoom out zooms back out, and past the whole picture
// closes the viewer, so the plain image returns. The viewer code is imported on first use (deep_zoom_viewer.js), so a page view
// that never zooms downloads nothing extra. Focus stays on the tool that was pressed. Without JavaScript the tools never appear.
// A thumbnail that changes the large image (media-viewer:shown) opens the new image in the viewer.
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

  // media-viewer:zoom, from the round tools
  async zoom(event) {
    if (event.detail.direction === "in") {
      if (!this.active && !(await this.start())) return
      this.tools.zoomIn(this.viewer)
    } else if (this.active) {
      if (this.tools.atHome(this.viewer)) this.close()
      else this.tools.zoomOut(this.viewer)
    }
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
