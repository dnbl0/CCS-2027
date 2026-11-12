import { Controller } from "@hotwired/stimulus"

// Zoom and pan for the record page's large image (CCS-57): a "Zoom and pan" toggle that swaps the image for an OpenSeadragon
// viewer, with buttons to zoom in, zoom out and reset. The viewer code is imported on first use (deep_zoom_viewer.js), so a page
// view that never zooms downloads nothing extra. Without JavaScript the toggle never appears and the image stays as it is.
// A thumbnail that changes the large image (media_viewer.js) tells this controller, which opens the new image in the viewer.
export default class extends Controller {
  static targets = [ "toggle", "stage", "controls", "navigator", "zoomIn", "zoomOut", "message" ]
  static values = { sources: Array, label: String, pill: Boolean, describedBy: String, navigatorId: String, autostart: Boolean }

  connect() {
    this.viewer = null
    // The viewer layout has grouped icon buttons instead of the toggle: they show now, and a press starts the viewer
    if (this.pillValue) {
      this.controlsTarget.hidden = false
      this.syncLimits()
    } else this.toggleTarget.hidden = false
    // The viewer layout's picture is the page's main thing: the viewer starts once the page has settled, without taking focus
    if (this.autostartValue) {
      const go = () => this.ensure(false)
      if ("requestIdleCallback" in window) requestIdleCallback(go, { timeout: 1500 }); else setTimeout(go, 300)
    }
    this.onFullscreen = () => { this.viewer?.forceResize(); this.applyTouchMode() }
    // The page's split layout resized the stage (the data panel opened or closed, or the view changed): the viewer follows
    this.onResized = () => requestAnimationFrame(() => this.viewer?.forceResize())
    window.addEventListener("viewer-split:resized", this.onResized)
    document.addEventListener("fullscreenchange", this.onFullscreen)
    // On a short screen (a phone held sideways) the viewer stops capturing touches and goes home, so the page can scroll past it;
    // full screen gives them back. Checked on resize, once it settles.
    this.onResize = () => { clearTimeout(this.resizeTimer); this.resizeTimer = setTimeout(() => this.applyTouchMode(), 300) }
    window.addEventListener("resize", this.onResize)
  }

  disconnect() {
    document.removeEventListener("fullscreenchange", this.onFullscreen)
    window.removeEventListener("resize", this.onResize)
    window.removeEventListener("viewer-split:resized", this.onResized)
    clearTimeout(this.resizeTimer)
    this.destroy()
  }

  applyTouchMode() {
    if (!this.viewer) return
    const short = window.innerHeight <= 500 && !document.fullscreenElement
    this.viewer.setMouseNavEnabled(!short)
    if (short) this.viewer.viewport.goHome()
  }

  // Zoom in and zoom out are disabled where the view cannot go further that way (and zoom out before the viewer is on)
  syncLimits() {
    // The navigator map matters only once the picture is zoomed past its home view
    if (this.viewer) this.element.classList.toggle("is-zoomed", this.viewer.viewport.getZoom() > this.viewer.viewport.getHomeZoom() * 1.05)
    else this.element.classList.remove("is-zoomed")
    if (!this.hasZoomInTarget) return
    const { canZoomIn, canZoomOut } = this.viewer ? this.tools.limits(this.viewer) : { canZoomIn: true, canZoomOut: false }
    this.zoomInTarget.disabled = !canZoomIn
    this.zoomOutTarget.disabled = !canZoomOut
  }

  // The image could not be opened: say so in a sentence, and leave the plain image
  fail() {
    this.close()
    if (this.hasMessageTarget) this.messageTarget.hidden = false
  }

  get image() { return this.element.closest("figure")?.querySelector("img.digital-assets__image") }
  get active() { return this.viewer !== null }

  toggle() { this.active ? this.close() : this.start() }

  // The pill's buttons act on a viewer that may not be on yet: start it first, once however fast the presses come
  async ensure(focus = true) {
    if (!this.active) {
      this.starting ||= this.start(focus).finally(() => { this.starting = null })
      await this.starting
    }
    return this.active
  }

  async start(focus = true) {
    if (this.hasToggleTarget) this.toggleTarget.disabled = true
    try {
      this.tools = await import("controllers/deep_zoom_viewer")
      const source = this.sourceFor(this.image?.getAttribute("src"))
      if (this.hasMessageTarget) this.messageTarget.hidden = true
      if (this.hasNavigatorTarget) this.navigatorTarget.hidden = false
      this.stageTarget.hidden = false // shown first: the viewer measures the box it is drawn in
      this.viewer = await this.tools.createViewer(this.stageTarget, source, {
        label: this.image?.alt, describedBy: this.describedByValue || undefined, navigatorId: this.hasNavigatorTarget ? this.navigatorIdValue : undefined
      })
      this.viewer.addHandler("open-failed", () => this.fail())
      this.viewer.addHandler("animation", () => this.syncLimits())
      this.viewer.addHandler("zoom", () => this.syncLimits())
      this.viewer.addHandler("animation-finish", () => this.syncLimits())
      this.applyTouchMode()
      this.syncLimits()
      this.element.classList.add("is-active")
      this.stageTarget.hidden = false
      if (!this.pillValue) this.controlsTarget.hidden = false
      if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-pressed", "true")
      if (focus) this.viewer.canvas.focus()
    } catch (_) {
      this.viewer = null // the viewer could not load: the plain image stays, and a sentence says so
      this.element.classList.remove("is-active")
      this.stageTarget.hidden = true
      if (this.hasNavigatorTarget) this.navigatorTarget.hidden = true
      if (this.hasMessageTarget) this.messageTarget.hidden = false
    } finally {
      if (this.hasToggleTarget) this.toggleTarget.disabled = false
    }
  }

  close() {
    this.destroy()
    this.element.classList.remove("is-active")
    this.stageTarget.hidden = true
    if (this.hasNavigatorTarget) this.navigatorTarget.hidden = true
    this.syncLimits()
    if (!this.pillValue) this.controlsTarget.hidden = true
    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-pressed", "false")
      this.toggleTarget.focus()
    }
  }

  destroy() {
    this.viewer?.destroy()
    this.viewer = null
  }

  async zoomIn() { if (await this.ensure()) this.tools.zoomIn(this.viewer) }
  async zoomOut() { if (await this.ensure()) this.tools.zoomOut(this.viewer) }
  async reset() { if (await this.ensure()) this.tools.reset(this.viewer) }

  // media-viewer:shown, from the thumbnails
  imageChanged(event) {
    if (!this.active) return
    const { src, alt } = event.detail
    this.tools.open(this.viewer, this.sourceFor(src), alt, this.describedByValue || undefined)
  }

  sourceFor(url) {
    return this.sourcesValue.find((source) => source.url === url) || { url, alt: this.labelValue }
  }
}
