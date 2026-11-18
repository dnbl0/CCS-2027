import { Controller } from "@hotwired/stimulus"

// Explore by place (app/views/explore/places.html.erb): the map, opt-in. Leaflet (vendored, vendor/javascript/leaflet.js) is
// loaded and the tile server first contacted only when the visitor presses "Show the map"; the button is a disclosure
// (aria-expanded, focus stays on it). Places close together on screen are grouped into one marker with their total; choosing a
// group zooms in, choosing a place opens a popup with a link to its records. Markers are buttons in the Tab order. Animations
// are off for visitors who ask for reduced motion. The lists beside the map do the same job without it.
const GROUP_PIXELS = 44

export default class extends Controller {
  static targets = ["button", "map"]
  static values = { markers: Array, tiles: String, attribution: String, showLabel: String, hideLabel: String }

  async toggle() {
    const open = this.buttonTarget.getAttribute("aria-expanded") === "true"
    this.buttonTarget.setAttribute("aria-expanded", String(!open))
    this.buttonTarget.textContent = open ? this.showLabelValue : this.hideLabelValue
    this.mapTarget.hidden = open
    if (open) return

    if (this.map) {
      this.map.invalidateSize()
      return
    }
    this.L = await import("leaflet")
    this.draw()
  }

  draw() {
    const L = this.L
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.map = L.map(this.mapTarget, { zoomAnimation: !reduce, fadeAnimation: !reduce, markerZoomAnimation: !reduce, worldCopyJump: true })
    this.map.attributionControl.setPrefix('<a href="https://leafletjs.com">Leaflet</a>')
    L.tileLayer(this.tilesValue, { attribution: this.attributionValue, maxZoom: 18 }).addTo(this.map)
    this.layer = L.layerGroup().addTo(this.map)
    const points = this.markersValue.map((marker) => [marker.lat, marker.lon])
    if (points.length) this.map.fitBounds(points, { padding: [24, 24], maxZoom: 6 })
    else this.map.setView([0, 0], 2)
    this.map.on("zoomend", () => this.group())
    this.group()
  }

  // Greedy grouping on screen pixels at the current zoom, biggest places first
  group() {
    const L = this.L
    const zoom = this.map.getZoom()
    const groups = []
    const sorted = [...this.markersValue].sort((a, b) => b.count - a.count)
    for (const marker of sorted) {
      const point = this.map.project([marker.lat, marker.lon], zoom)
      const near = groups.find((group) => group.point.distanceTo(point) < GROUP_PIXELS)
      if (near) near.members.push(marker)
      else groups.push({ point, members: [marker] })
    }
    this.layer.clearLayers()
    for (const group of groups) this.layer.addLayer(group.members.length === 1 ? this.place(group.members[0]) : this.cluster(group))
  }

  place(marker) {
    const L = this.L
    const name = `${marker.label}: ${this.records(marker.count)}`
    const icon = L.divIcon({ className: "explore-map__pin", html: this.badge(marker.count), iconSize: null })
    const pin = L.marker([marker.lat, marker.lon], { icon, keyboard: true, title: name })
    pin.bindPopup(() => this.popup(marker))
    // The popup's link takes the focus, and the marker gets it back when the popup closes (Escape, or its close button)
    pin.on("popupopen", (event) => {
      const element = event.popup.getElement()
      element?.addEventListener("keydown", (key) => { if (key.key === "Escape") this.map.closePopup() })
      element?.querySelector(".leaflet-popup-content a[href]")?.focus()
    })
    pin.on("popupclose", (event) => {
      if (event.popup.getElement()?.contains(document.activeElement) || document.activeElement === document.body) pin.getElement()?.focus()
    })
    pin.on("add", () => this.label(pin, name))
    return pin
  }

  cluster(group) {
    const L = this.L
    const total = group.members.reduce((sum, marker) => sum + marker.count, 0)
    const name = `${group.members.length} places, ${this.records(total)}: zoom in`
    const icon = L.divIcon({ className: "explore-map__pin explore-map__pin--group", html: this.badge(total), iconSize: null })
    const bounds = L.latLngBounds(group.members.map((marker) => [marker.lat, marker.lon]))
    const pin = L.marker(bounds.getCenter(), { icon, keyboard: true, title: name })
    pin.on("click", () => this.map.fitBounds(bounds.pad(0.5), { maxZoom: Math.min(this.map.getZoom() + 3, 18) }))
    pin.on("add", () => this.label(pin, name))
    return pin
  }

  label(pin, name) {
    const element = pin.getElement()
    element.setAttribute("role", "button")
    element.setAttribute("aria-label", name)
  }

  badge(count) {
    const span = document.createElement("span")
    span.className = "explore-map__marker"
    span.setAttribute("aria-hidden", "true")
    span.textContent = count.toLocaleString("en-AU") // the same figure as in the marker's name, so the name holds the visible text
    return span.outerHTML
  }

  popup(marker) {
    const box = document.createElement("div")
    const heading = document.createElement("p")
    heading.className = "explore-map__popup-title"
    heading.textContent = marker.label
    const link = document.createElement("a")
    link.href = marker.href
    link.textContent = `See ${this.records(marker.count)} from ${marker.label}`
    box.append(heading, link)
    return box
  }

  records(count) {
    return `${count.toLocaleString("en-AU")} ${count === 1 ? "record" : "records"}`
  }

  disconnect() {
    this.map?.remove()
    this.map = null
  }
}
