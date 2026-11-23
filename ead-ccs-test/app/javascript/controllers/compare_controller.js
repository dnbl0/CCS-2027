import { Controller } from "@hotwired/stimulus"

// The comparison page (CCS-58): two to four panes, each an OpenSeadragon viewer, with zoom and pan that can be linked so the
// panes move together ("Move images together"). Each pane's image can be changed from its own picker (its heading, "Image 2 of 4",
// follows); each has Zoom in, Zoom out and Reset; one Full screen shows the whole comparison, toolbar and all. The viewer code is imported when this page loads, never on other pages. Without JavaScript each pane is its plain
// image and the page still shows the records side by side; the controls stay invisible (they hold their space, so nothing moves
// when they appear) because they would do nothing.
export default class extends Controller {
  static targets = [ "pane", "link" ]

  async connect() {
    this.viewers = new Map()
    this.syncing = false
    this.onFullscreen = () => this.syncFullscreen()
    document.addEventListener("fullscreenchange", this.onFullscreen)

    try {
      this.tools = await import("controllers/deep_zoom_viewer")
      await Promise.all(this.paneTargets.map((pane) => this.setUp(pane)))
      this.element.classList.add("is-ready")
    } catch (_) { /* the viewer could not load: the plain images stay and the controls stay hidden */ }
  }

  disconnect() {
    document.removeEventListener("fullscreenchange", this.onFullscreen)
    this.viewers?.forEach((viewer) => viewer.destroy())
  }

  async setUp(pane) {
    const sources = JSON.parse(pane.dataset.sources)
    const select = pane.querySelector("select")
    const index = select ? Number(select.value) : 0
    const stage = pane.querySelector("[data-stage]")
    const fallback = stage.querySelector("img")
    const viewer = await this.tools.createViewer(stage, sources[index], { label: sources[index].alt })
    fallback?.remove()
    this.viewers.set(pane, viewer)
    viewer.addHandler("zoom", () => { pane.dataset.zoom = viewer.viewport.getZoom().toFixed(3); this.follow(pane) })
    viewer.addHandler("pan", () => this.follow(pane))
    // the pane the visitor is moving leads (a viewer fitting its own image as it opens is not a move to copy)
    const lead = () => { this.leader = pane }
    ;[ "pointerdown", "wheel", "keydown", "touchstart" ].forEach((type) => stage.addEventListener(type, lead, { passive: true }))
  }

  // the pane the visitor is moving sets the others to the same zoom (relative to each one's fit) and centre, when linked
  follow(from) {
    if (this.syncing || !this.linkTarget.checked || from !== this.leader) return
    const source = this.viewers.get(from).viewport
    this.syncing = true
    try {
      // each pane by the same proportion of its own fit (images of different shapes fit at different zooms), to the same place
      const factor = source.getZoom() / source.getHomeZoom()
      this.viewers.forEach((viewer, pane) => {
        if (pane === from) return
        viewer.viewport.zoomTo(viewer.viewport.getHomeZoom() * factor, null, true)
        viewer.viewport.panTo(source.getCenter(), true)
      })
    } finally {
      this.syncing = false
    }
  }

  // a pane's selector: show that image in the pane
  choose(event) {
    const pane = event.currentTarget.closest("[data-compare-target=pane]")
    const source = JSON.parse(pane.dataset.sources)[Number(event.currentTarget.value)]
    this.leader = null // the new image fits itself; the others stay as they are
    this.tools.open(this.viewers.get(pane), source, source.alt)
    pane.querySelector("[data-pane-image-name]").textContent = source.alt
    const heading = pane.querySelector("[data-pane-heading]")
    if (heading) heading.textContent = event.currentTarget.selectedOptions[0].textContent
  }

  paneOf(event) { return event.currentTarget.closest("[data-compare-target=pane]") }
  zoomIn(event) { this.leader = this.paneOf(event); this.tools.zoomIn(this.viewers.get(this.leader)) }
  zoomOut(event) { this.leader = this.paneOf(event); this.tools.zoomOut(this.viewers.get(this.leader)) }
  reset(event) { this.leader = this.paneOf(event); this.tools.reset(this.viewers.get(this.leader)) }

  // the whole comparison full screen (the panes side by side are the point), or back
  async fullscreen() {
    try {
      if (document.fullscreenElement) await document.exitFullscreen()
      else await this.element.requestFullscreen()
    } catch (_) { /* refused: the button does nothing */ }
  }

  // Escape leaves full screen natively; the button's words and the viewers' sizes follow
  syncFullscreen() {
    const on = document.fullscreenElement === this.element
    this.element.classList.toggle("is-fullscreen", on)
    const label = this.element.querySelector("[data-fullscreen-label]")
    if (label) label.textContent = on ? this.element.dataset.exitLabel : this.element.dataset.enterLabel
    this.viewers.forEach((viewer) => viewer.forceResize())
  }
}
