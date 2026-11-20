import { Controller } from "@hotwired/stimulus"

// The record's media viewer (DigitalAssetsComponent; Figma "Media viewer", after Europeana's item viewer).
//
// - ⋮ opens the media information on the left at the viewer's full height: focus moves to its heading, Close or Escape returns it
//   to ⋮. Where the viewer is narrow the panel covers the media, so the rest of the viewer is made inert while it is open.
// - Rotate, zoom and reset are passed to the zoom viewer (deep_zoom_controller listens for media-viewer:zoom on window), which
//   reports back with deep-zoom:state; the controls are disabled (aria-disabled, still focusable, the reason in their tooltip)
//   at the limits, and the readout shows the zoom.
// - A thumbnail shows its image (a modified click on an open image's link still opens the file); Previous and Next step through
//   them and stop at the ends; arrow keys move between thumbnails. Hide thumbnails closes the column for the rest of the visit.
// - Full screen is for the whole viewer.
// Without JavaScript none of the script-only controls appear, and the thumbnails of open images are links to their files.
const THUMBS_KEY = "ccs-media-viewer-thumbnails"

export default class extends Controller {
  static targets = [ "stage", "image", "panel", "panelHeading", "infoButton", "tool", "rotateLeft", "rotateRight", "zoomIn", "zoomOut", "reset",
    "fullscreenGroup", "fullscreenButton", "readout", "readoutLevel", "readoutHint", "thumbs", "thumbList", "thumb", "thumbsFooter",
    "previous", "next", "hideThumbs", "showThumbs", "status" ]
  static values = { labels: Object }

  connect() {
    this.toolTargets.forEach((group) => { group.hidden = false })
    if (this.hasThumbsFooterTarget) this.thumbsFooterTarget.hidden = false
    if (this.hasFullscreenGroupTarget && document.fullscreenEnabled) this.fullscreenGroupTarget.hidden = false
    this.onFullscreen = () => this.syncFullscreen()
    document.addEventListener("fullscreenchange", this.onFullscreen)
    this.zoom = { active: false, zoom: 100, atHome: true, atMax: false, rotation: 0 }
    this.syncTools()
    this.syncSteps()
    if (this.hasThumbsTarget && this.storedThumbs() === "hidden") this.hideThumbnails({ focus: false })
  }

  disconnect() {
    document.removeEventListener("fullscreenchange", this.onFullscreen)
    clearTimeout(this.readoutTimer)
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

  // --- Media information (CCS-422)
  get panelOpen() { return this.hasPanelTarget && !this.panelTarget.hidden }
  get narrow() { return this.element.getBoundingClientRect().width < 600 }

  togglePanel() { this.panelOpen ? this.closePanel() : this.openPanel() }

  openPanel() {
    if (!this.hasPanelTarget) return
    this.panelTarget.hidden = false
    this.element.classList.add("has-information")
    this.infoButtonTarget.setAttribute("aria-expanded", "true")
    if (this.narrow) this.inertBehindPanel(true)
    this.panelHeadingTarget.focus()
  }

  closePanel() {
    if (!this.panelOpen) return
    this.panelTarget.hidden = true
    this.element.classList.remove("has-information")
    this.infoButtonTarget.setAttribute("aria-expanded", "false")
    this.inertBehindPanel(false)
    this.infoButtonTarget.focus()
  }

  inertBehindPanel(on) {
    this.element.querySelectorAll(".media-viewer__stage, .media-viewer__thumbs").forEach((part) => { part.inert = on })
  }

  keydown(event) {
    if (event.key === "Escape" && this.panelOpen) { event.preventDefault(); this.closePanel(); return }
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

  // --- Rotate and zoom (deep_zoom_controller does them)
  rotateLeft(event) { this.send(event, { direction: "rotate", degrees: -90 }) }
  rotateRight(event) { this.send(event, { direction: "rotate", degrees: 90 }) }
  zoomIn(event) { this.send(event, { direction: "in" }) }
  zoomOut(event) { this.send(event, { direction: "out" }) }
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
    const fitted = !active || (atHome && rotation === 0)
    if (this.hasZoomInTarget) this.setDisabled(this.zoomInTarget, atMax, this.label("at_max"))
    if (this.hasZoomOutTarget) this.setDisabled(this.zoomOutTarget, !active || atHome, this.label("at_fit"))
    if (this.hasResetTarget) this.setDisabled(this.resetTarget, fitted, this.label("at_fit"))
    this.syncReadout()
  }

  // The readout shows the zoom while zoomed in; its text settles before it is announced (role=status)
  syncReadout() {
    if (!this.hasReadoutTarget) return
    const { active, zoom, atHome, atMax } = this.zoom
    clearTimeout(this.readoutTimer)
    if (!active || atHome) { this.readoutTarget.hidden = true; return }
    this.readoutTarget.hidden = false
    this.readoutTimer = setTimeout(() => {
      this.readoutLevelTarget.textContent = atMax ? this.label("max_zoom") : this.label("zoom_level", { percent: zoom })
    }, 250)
  }

  // --- Thumbnails
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
    if (target) { this.display(target); target.scrollIntoView({ block: "nearest", inline: "nearest" }) }
  }

  display(thumb) {
    if (!this.hasImageTarget) return
    this.imageTarget.removeAttribute("width")
    this.imageTarget.removeAttribute("height")
    this.imageTarget.src = thumb.dataset.mediaViewerLarge
    this.imageTarget.alt = thumb.dataset.mediaViewerAlt
    this.thumbTargets.forEach((other) => { if (other === thumb) other.setAttribute("aria-current", "true"); else other.removeAttribute("aria-current") })
    this.syncSteps()
    this.dispatch("shown", { detail: { src: this.imageTarget.getAttribute("src"), alt: this.imageTarget.alt } }) // the zoom viewer resets
    this.announce(this.label("shown", { position: thumb.dataset.mediaViewerPosition, count: this.thumbTargets.length }))
  }

  syncSteps() {
    if (!this.hasPreviousTarget) return
    const index = this.currentIndex
    this.setDisabled(this.previousTarget, index === 0, this.label("at_start"))
    this.setDisabled(this.nextTarget, index === this.thumbTargets.length - 1, this.label("at_end"))
  }

  hideThumbnails({ focus = true } = {}) {
    if (!this.hasThumbsTarget) return
    this.thumbsTarget.hidden = true
    this.element.classList.add("has-hidden-thumbnails")
    this.showThumbsTarget.hidden = false
    this.showThumbsTarget.setAttribute("aria-expanded", "false")
    this.storeThumbs("hidden")
    if (focus) this.showThumbsTarget.focus()
  }

  showThumbnails() {
    this.thumbsTarget.hidden = false
    this.element.classList.remove("has-hidden-thumbnails")
    this.showThumbsTarget.hidden = true
    this.storeThumbs("shown")
    const current = this.thumbTargets[this.currentIndex]
    current?.focus()
    current?.scrollIntoView({ block: "nearest", inline: "nearest" })
  }

  storedThumbs() { try { return sessionStorage.getItem(THUMBS_KEY) } catch { return null } }
  storeThumbs(value) { try { sessionStorage.setItem(THUMBS_KEY, value) } catch { /* private mode: the choice lasts for this page */ } }

  // --- Full screen
  async toggleFullscreen() {
    try {
      if (document.fullscreenElement) await document.exitFullscreen()
      else await this.element.requestFullscreen()
    } catch { /* refused: nothing changes */ }
  }

  syncFullscreen() {
    const on = document.fullscreenElement === this.element
    this.element.classList.toggle("is-fullscreen", on)
    if (!this.hasFullscreenButtonTarget) return
    const name = this.label(on ? "exit_full_screen" : "full_screen")
    this.fullscreenButtonTarget.setAttribute("aria-pressed", String(on))
    this.fullscreenButtonTarget.setAttribute("aria-label", name)
    this.fullscreenButtonTarget.title = name
  }
}
