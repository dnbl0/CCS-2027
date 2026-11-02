import { Controller } from "@hotwired/stimulus"

// The comparison page (CCS-58): two to four panes, each an OpenSeadragon viewer, with zoom and pan that can be linked so the
// panes move together. Each pane's image can be changed from its own selector; each has zoom in, zoom out, reset and full screen
// buttons. The viewer code is imported when this page loads, never on other pages. Without JavaScript each pane is its plain
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
  }

  // the pane being moved sets the others to the same zoom and centre, when linked
  follow(from) {
    if (this.syncing || !this.linkTarget.checked) return
    const source = this.viewers.get(from).viewport
    this.syncing = true
    try {
      this.viewers.forEach((viewer, pane) => {
        if (pane === from) return
        viewer.viewport.zoomTo(source.getZoom(), null, true)
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
    this.tools.open(this.viewers.get(pane), source, source.alt)
    pane.querySelector("[data-pane-image-name]").textContent = source.alt
  }

  paneOf(event) { return event.currentTarget.closest("[data-compare-target=pane]") }
  zoomIn(event) { this.tools.zoomIn(this.viewers.get(this.paneOf(event))) }
  zoomOut(event) { this.tools.zoomOut(this.viewers.get(this.paneOf(event))) }
  reset(event) { this.tools.reset(this.viewers.get(this.paneOf(event))) }

  async fullscreen(event) {
    const pane = this.paneOf(event)
    try {
      if (document.fullscreenElement) await document.exitFullscreen()
      else await pane.requestFullscreen()
    } catch (_) { /* refused: the button does nothing */ }
  }

  // Escape leaves full screen natively; the button's name and the viewer's size follow
  syncFullscreen() {
    this.paneTargets.forEach((pane) => {
      const on = document.fullscreenElement === pane
      pane.classList.toggle("is-fullscreen", on)
      const button = pane.querySelector("[data-fullscreen]")
      if (button) button.textContent = on ? "Exit full screen" : "Full screen"
      this.viewers.get(pane)?.forceResize()
    })
  }
}
