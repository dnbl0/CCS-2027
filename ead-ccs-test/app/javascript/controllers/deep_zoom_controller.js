import { Controller } from "@hotwired/stimulus"

// Zoom, pan and rotate for the record page's images (CCS-57), inside the zoom modal (DigitalAssetsComponent). The media viewer sends
// media-viewer:zoom: "open" (with the image's url) starts an OpenSeadragon viewer filling the modal, or opens another image in it;
// "in", "out", "rotate" and "reset" move the view; "close" puts the viewer away. The viewer code is imported on first use
// (deep_zoom_viewer.js), so a page view that never zooms downloads nothing extra. The mouse wheel does not zoom; buttons, the
// keyboard, a double click and a pinch do. After every change it reports deep-zoom:state for the tools.
export default class extends Controller {
  static targets = [ "stage" ]
  static values = { sources: Array, label: String }

  connect() { this.viewer = null }
  disconnect() { this.destroy() }

  get active() { return this.viewer !== null }

  // media-viewer:zoom: { direction: "open" | "in" | "out" | "rotate" | "reset" | "close", url, alt, degrees }
  async zoom(event) {
    const { direction, url, alt, degrees } = event.detail
    if (direction === "close") { this.destroy(); this.focused = false; this.stageTarget.hidden = true; return }
    if (direction === "open") { await this.show(url, alt); this.report(); return }
    if (!this.active) return
    if (direction === "in") this.tools.zoomIn(this.viewer)
    else if (direction === "out") this.tools.zoomOut(this.viewer)
    else if (direction === "rotate") this.tools.rotate(this.viewer, degrees)
    else if (direction === "reset") { this.viewer.viewport.setRotation(0); this.tools.reset(this.viewer) }
    this.report()
  }

  async show(url, alt) {
    const source = this.sourceFor(url, alt)
    try {
      this.tools ||= await import("controllers/deep_zoom_viewer")
      this.stageTarget.hidden = false
      if (this.active) {
        this.viewer.viewport.setRotation(0)
        this.tools.open(this.viewer, source, source.alt)
      } else {
        this.viewer = await this.tools.createViewer(this.stageTarget, source, { label: source.alt })
        this.viewer.addHandler("animation-finish", () => this.report())
        this.viewer.addHandler("rotate", () => this.report())
      }
      const first = !this.focused
      await this.tools.opened(this.viewer)
      // the first image takes focus, so the arrow keys pan at once; Previous and Next keep it where it is
      if (first) { this.viewer.canvas.focus({ preventScroll: true }); this.focused = true }
    } catch (_) {
      this.destroy() // the viewer could not load: the modal stays, with its close button
    }
  }

  // Tells the media viewer where the view is (deep-zoom:state, bubbling to it), so its tools and readout follow
  report() {
    const detail = this.active ? { active: true, ...this.tools.state(this.viewer) } : { active: false, zoom: 100, atHome: true, atMax: false, rotation: 0 }
    this.dispatch("state", { detail })
  }

  destroy() {
    this.viewer?.destroy()
    this.viewer = null
  }

  sourceFor(url, alt) {
    return this.sourcesValue.find((source) => source.url === url) || { url, alt: alt || this.labelValue }
  }
}
