import { Controller } from "@hotwired/stimulus"

// The record's media (DigitalAssetsComponent, Figma Record/IIIF viewer).
//
// - A thumbnail shows its image on the panel (a modified click on an open image's link still opens the file); arrow keys, Home and
//   End move between thumbnails.
// - Zoom opens the image full screen in a modal <dialog> (focus is held inside it, Escape closes it and focus returns to Zoom). The
//   zoom viewer (deep_zoom_controller, listening for media-viewer:zoom on window) opens the image on show and reports back with
//   deep-zoom:state; the tools are disabled at their limits (aria-disabled, still focusable, the reason in their tooltip) and the
//   readout says the zoom. Previous and Next step through the images inside the modal and stop at the ends.
// - Media information opens a drawer from the right, also a modal <dialog>. The counter under the thumbnails and the zoom's
//   "Image N of M" follow the image on show; in Download, the size chosen is the file Download image fetches.
// Without JavaScript Zoom never appears; the image, the thumbnails and Download still work.
export default class extends Controller {
  static targets = [ "image", "thumb", "zoomButton", "zoomDialog", "zoomIn", "zoomOut", "rotateRight", "reset", "previous", "next",
    "readout", "infoButton", "infoDialog", "status", "counter", "position", "downloadLink" ]
  static values = { labels: Object }

  connect() {
    if (this.hasZoomButtonTarget) this.zoomButtonTarget.hidden = false
    this.zoom = { active: false, zoom: 100, atHome: true, atMax: false, rotation: 0 }
    this.syncTools()
    this.syncSteps()
  }

  // Turbo is replacing the page: do not leave a modal open in the cached copy
  disconnect() {
    clearTimeout(this.readoutTimer)
    if (this.hasZoomDialogTarget && this.zoomDialogTarget.open) this.zoomDialogTarget.close()
    if (this.hasInfoDialogTarget && this.infoDialogTarget.open) this.infoDialogTarget.close()
  }

  label(key, values = {}) {
    return (this.labelsValue[key] || key).replace(/%\{(\w+)\}/g, (_, name) => values[name] ?? "")
  }

  disabled(button) { return button?.getAttribute("aria-disabled") === "true" }

  setDisabled(button, disabled, reason) {
    if (!button) return
    if (disabled) button.setAttribute("aria-disabled", "true"); else button.removeAttribute("aria-disabled")
    button.title = disabled && reason ? reason : button.getAttribute("aria-label")
  }

  announce(text) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = ""
    requestAnimationFrame(() => { this.statusTarget.textContent = text })
  }

  // --- Zoom
  openZoom() {
    if (!this.hasZoomDialogTarget || this.zoomDialogTarget.open) return
    this.zoomDialogTarget.showModal()
    this.openImage()
  }

  closeZoom() { if (this.hasZoomDialogTarget) this.zoomDialogTarget.close() }

  // The dialog closed (Close, Escape): the viewer is put away, so the next Zoom starts at the whole picture
  zoomClosed() {
    this.dispatch("zoom", { detail: { direction: "close" } })
    this.zoom = { active: false, zoom: 100, atHome: true, atMax: false, rotation: 0 }
    this.syncTools()
  }

  openImage() {
    if (!this.hasImageTarget) return
    this.dispatch("zoom", { detail: { direction: "open", url: this.imageTarget.getAttribute("src"), alt: this.imageTarget.alt } })
  }

  zoomIn(event) { this.send(event, { direction: "in" }) }
  zoomOut(event) { this.send(event, { direction: "out" }) }
  rotateRight(event) { this.send(event, { direction: "rotate", degrees: 90 }) }
  reset(event) { this.send(event, { direction: "reset" }) }

  send(event, detail) {
    if (this.disabled(event.currentTarget)) return
    this.dispatch("zoom", { detail })
  }

  // deep-zoom:state: { active, zoom (percent of the whole picture), atHome, atMax, rotation }
  zoomChanged(event) {
    const before = this.zoom.rotation
    this.zoom = event.detail
    this.syncTools()
    if (this.zoom.rotation !== before) this.announce(this.label("rotated", { degrees: this.zoom.rotation }))
  }

  syncTools() {
    const { active, atHome, atMax, rotation } = this.zoom
    if (this.hasZoomInTarget) this.setDisabled(this.zoomInTarget, active && atMax, this.label("at_max"))
    if (this.hasZoomOutTarget) this.setDisabled(this.zoomOutTarget, !active || atHome, this.label("at_fit"))
    if (this.hasResetTarget) this.setDisabled(this.resetTarget, !active || (atHome && rotation === 0), this.label("at_fit"))
    this.syncReadout()
  }

  // The readout says the zoom once it settles (role=status), and nothing at the whole picture
  syncReadout() {
    if (!this.hasReadoutTarget) return
    const { active, zoom, atHome, atMax } = this.zoom
    clearTimeout(this.readoutTimer)
    this.readoutTimer = setTimeout(() => {
      this.readoutTarget.textContent = !active || atHome ? "" : (atMax ? this.label("max_zoom") : this.label("zoom_level", { percent: zoom }))
    }, 250)
  }

  // --- Thumbnails, and Previous and Next in the zoom modal
  get currentIndex() { return Math.max(this.thumbTargets.findIndex((thumb) => thumb.getAttribute("aria-current") === "true"), 0) }

  show(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.button) return
    event.preventDefault()
    this.display(event.currentTarget)
  }

  previous(event) { if (!this.disabled(event.currentTarget)) this.step(-1) }
  next(event) { if (!this.disabled(event.currentTarget)) this.step(1) }

  step(offset) {
    const thumbs = this.thumbTargets
    const target = thumbs[Math.min(Math.max(this.currentIndex + offset, 0), thumbs.length - 1)]
    if (target) this.display(target)
  }

  display(thumb) {
    if (!this.hasImageTarget) return
    this.imageTarget.removeAttribute("width")
    this.imageTarget.removeAttribute("height")
    this.imageTarget.src = thumb.dataset.mediaViewerLarge
    this.imageTarget.alt = thumb.dataset.mediaViewerAlt
    this.thumbTargets.forEach((other) => { if (other === thumb) other.setAttribute("aria-current", "true"); else other.removeAttribute("aria-current") })
    this.syncSteps()
    const position = this.label("position", { position: thumb.dataset.mediaViewerPosition, count: this.thumbTargets.length })
    if (this.hasCounterTarget) this.counterTarget.textContent = position
    if (this.hasPositionTarget) this.positionTarget.textContent = position
    if (this.hasZoomDialogTarget && this.zoomDialogTarget.open) this.openImage()
    this.announce(this.label("shown", { position: thumb.dataset.mediaViewerPosition, count: this.thumbTargets.length }))
  }

  syncSteps() {
    if (!this.hasPreviousTarget) return
    const index = this.currentIndex
    this.setDisabled(this.previousTarget, index === 0, this.label("at_start"))
    this.setDisabled(this.nextTarget, index === this.thumbTargets.length - 1, this.label("at_end"))
  }

  keydown(event) {
    const thumb = event.target.closest?.("[data-media-viewer-target~='thumb']")
    if (!thumb) return
    const offsets = { ArrowLeft: -1, ArrowUp: -1, ArrowRight: 1, ArrowDown: 1 }
    const thumbs = this.thumbTargets
    let index = thumbs.indexOf(thumb)
    if (event.key in offsets) index = Math.min(Math.max(index + offsets[event.key], 0), thumbs.length - 1)
    else if (event.key === "Home") index = 0
    else if (event.key === "End") index = thumbs.length - 1
    else return
    event.preventDefault()
    thumbs[index].focus()
  }

  // --- Download: the size chosen is the file the Download image link fetches
  chooseSize(event) {
    if (this.hasDownloadLinkTarget) this.downloadLinkTarget.href = event.currentTarget.value
  }

  // --- Media information (CCS-422)
  openInfo() { if (this.hasInfoDialogTarget && !this.infoDialogTarget.open) this.infoDialogTarget.showModal() }
  closeInfo() { if (this.hasInfoDialogTarget) this.infoDialogTarget.close() }
  closeInfoOnBackdrop(event) { if (event.target === this.infoDialogTarget) this.closeInfo() }
}
