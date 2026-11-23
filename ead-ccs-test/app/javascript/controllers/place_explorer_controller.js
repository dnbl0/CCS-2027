import { Controller } from "@hotwired/stimulus"

// Explore by place (app/views/explore/places.html.erb; after Airbnb's search with a map, 2026-11): the places as picture cards beside a
// map whose pins carry each place's number of records. The region chips and the name box narrow the cards and the pins together; once
// the map is shown, the cards are the places in view (unless "Update the list as I move the map" is turned off), and the places in view
// with no card are listed by name under them. Hovering or focusing a card marks its pin.
//
// The map is opt-in: Leaflet (vendored) is loaded and the tile server first contacted only when the visitor presses Show the map. The
// choice is then remembered in this browser (localStorage) until Hide the map, so the map comes back on the next visit. Pins are buttons
// in the Tab order; a place's pin opens a popup whose link takes the focus, and Escape gives the focus back to the pin. Places close
// together on screen are one pin with their total, which zooms in. Animations are off for visitors who ask for reduced motion.
//
// Before the map, its panel shows the places as dots drawn from the page's own data (no tile is fetched for it). The cards come a page
// at a time (Show more places). On a phone the list comes first and a floating button swaps the list and the map.
const GROUP_PIXELS = 48
const PAGE = 18 // cards at a time, as Airbnb's pages
const REMEMBER = "ccs:place-map"
const MORE = 24 // names of places without a card, at most

export default class extends Controller {
  static targets = ["card", "list", "status", "empty", "more", "moreHeading", "moreList", "moreButton", "consent", "showButton", "stage", "map", "follow", "chip", "query", "dots", "switch"]
  static values = { markers: Array, tiles: String, attribution: String, words: Object }

  connect() {
    this.places = this.markersValue.map((place) => ({ ...place, search: `${place.label} ${place.where || ""}`.toLowerCase() }))
    this.words = this.wordsValue
    this.region = ""
    this.text = ""
    this.pins = new Map() // a place's key => the pin that shows it (its own, or its group's)
    this.limit = PAGE
    this.drawDots()
    if (this.remembered()) this.show({ restoring: true })
    else this.refresh()
  }

  disconnect() {
    this.map?.remove()
    this.map = null
    clearTimeout(this.saying)
  }

  // ---- the visitor's choices

  choose(event) {
    this.region = event.currentTarget.dataset.region
    this.chipTargets.forEach((chip) => chip.setAttribute("aria-pressed", String(chip === event.currentTarget)))
    if (this.map) this.frame(this.matching())
    this.refresh({ pins: true })
  }

  find() {
    this.text = this.queryTarget.value.trim().toLowerCase()
    this.refresh({ pins: true })
  }

  async show({ restoring = false } = {}) {
    this.remember(true)
    this.consentTarget.hidden = true
    this.stageTarget.hidden = false
    this.element.classList.add("has-map")
    if (!this.map) {
      this.L = await import("leaflet")
      this.draw()
    }
    this.refresh({ pins: true, more: true })
    if (!restoring) this.followTarget.focus({ preventScroll: true }) // the button that was pressed is gone: the focus goes to the map's first control
  }

  hide() {
    this.remember(false)
    this.map?.remove()
    this.map = null
    this.pins.clear()
    this.stageTarget.hidden = true
    this.consentTarget.hidden = false
    this.element.classList.remove("has-map")
    this.refresh()
    this.showButtonTarget.focus()
  }

  // ---- what is shown

  matching() {
    return this.places.filter((place) => (!this.region || place.region === this.region) && (!this.text || place.search.includes(this.text)))
  }

  // The list follows the map only while the map can be seen (on a phone, the list view hides it)
  following() { return Boolean(this.map) && this.followTarget.checked && this.mapTarget.offsetWidth > 0 }

  inView(place) {
    if (!this.following()) return true
    const bounds = this.map.getBounds()
    if (place.lat < bounds.getSouth() || place.lat > bounds.getNorth()) return false
    const west = bounds.getWest()
    const span = bounds.getEast() - west
    return span >= 360 || ((((place.lon - west) % 360) + 360) % 360) <= span // the map may have been panned round the world
  }

  // The cards (and, when the filters changed, the pins) for the current choices
  // more: keep the cards already shown (Show more places); any other change starts again at the first page
  refresh({ pins = false, more = false } = {}) {
    if (!more) this.limit = PAGE
    const matching = this.matching()
    const here = matching.filter((place) => this.inView(place))
    const keys = new Set(here.filter((place) => place.card).map((place) => String(place.key)))
    let shown = 0
    this.cardTargets.forEach((card) => {
      const fits = keys.has(card.dataset.key) && shown < this.limit
      if (fits) shown += 1
      card.hidden = !fits
    })
    const left = keys.size - shown
    this.moreButtonTarget.hidden = left <= 0
    this.moreButtonTarget.textContent = this.word("show_more", { count: left.toLocaleString("en-AU") })
    this.emptyTarget.hidden = keys.size > 0
    this.others(here.filter((place) => !place.card))
    this.say(keys.size)
    if (pins && this.map) this.group(matching)
  }

  showMore() {
    const first = this.cardTargets.filter((card) => !card.hidden).length
    this.limit += PAGE
    this.refresh({ more: true })
    // the focus goes to the first new card, so a keyboard user carries on from where the list grew
    this.cardTargets.filter((card) => !card.hidden)[first]?.querySelector("a")?.focus()
  }

  // On a phone: the list or the map (the map's panel asks before the map is loaded, as on a wide screen)
  switch() {
    const toMap = !this.element.classList.contains("is-map-view")
    this.element.classList.toggle("is-map-view", toMap)
    this.switchTarget.textContent = this.word(toMap ? "switch_list" : "switch_map")
    if (toMap && this.map) {
      this.map.invalidateSize()
      if (this.unframed) { this.frame(this.matching()); this.unframed = false }
    }
    this.refresh({ pins: true })
    window.scrollTo({ top: this.element.offsetTop, behavior: "instant" })
  }

  // Each place a dot where it is (longitude across, latitude up), bigger for more records: the map's preview before it is loaded
  drawDots() {
    if (!this.hasDotsTarget) return
    const svg = "http://www.w3.org/2000/svg"
    const seen = new Map()
    for (const place of this.places) {
      const spot = `${Math.round(place.lon)},${Math.round(place.lat)}`
      seen.set(spot, (seen.get(spot) || 0) + place.count)
    }
    const dots = [...seen].map(([spot, count]) => {
      const [lon, lat] = spot.split(",").map(Number)
      const dot = document.createElementNS(svg, "circle")
      dot.setAttribute("cx", lon + 180)
      dot.setAttribute("cy", 90 - lat)
      dot.setAttribute("r", (0.9 + Math.log10(count + 1) * 0.55).toFixed(2))
      return dot
    })
    this.dotsTarget.replaceChildren(...dots)
  }

  others(places) {
    this.moreTarget.hidden = places.length === 0
    if (!places.length) return
    this.moreHeadingTarget.textContent = this.word("more", { count: places.length.toLocaleString("en-AU") })
    this.moreListTarget.replaceChildren(...places.slice(0, MORE).map((place) => {
      const item = document.createElement("li")
      const link = document.createElement("a")
      link.href = place.href
      link.className = "place-explorer__more-link"
      link.textContent = place.label
      const count = document.createElement("span")
      count.className = "place-explorer__more-count"
      count.textContent = ` ${this.records(place.count)}`
      link.append(count)
      item.append(link)
      return item
    }))
  }

  // The status line, said once the visitor stops (a screen reader is not read every step of a drag or of typing)
  say(count) {
    const parts = [this.word(count === 1 ? "shown_one" : "shown_other", { count: count.toLocaleString("en-AU") })]
    if (this.region) parts.push(this.word("in_region", { region: this.region }))
    if (this.text) parts.push(this.word("matching", { text: this.queryTarget.value.trim() }))
    if (this.following()) parts.push(this.word("in_view"))
    clearTimeout(this.saying)
    this.saying = setTimeout(() => { this.statusTarget.textContent = parts.join(" ") }, 400)
  }

  // ---- a card and its pin

  mark(event) {
    const pin = this.pins.get(event.currentTarget.dataset.key)
    if (!pin) return
    pin.getElement()?.classList.add("is-marked")
    pin.setZIndexOffset(1000)
  }

  unmark(event) {
    if (event.type === "focusout" && event.currentTarget.contains(event.relatedTarget)) return
    const pin = this.pins.get(event.currentTarget.dataset.key)
    if (!pin) return
    pin.getElement()?.classList.remove("is-marked")
    pin.setZIndexOffset(0)
  }

  // ---- the map

  draw() {
    const L = this.L
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.map = L.map(this.mapTarget, { minZoom: 2, zoomAnimation: !reduce, fadeAnimation: !reduce, markerZoomAnimation: !reduce, worldCopyJump: true })
    this.map.attributionControl.setPrefix('<a href="https://leafletjs.com">Leaflet</a>')
    L.tileLayer(this.tilesValue, { attribution: this.attributionValue, maxZoom: 18 }).addTo(this.map)
    this.layer = L.layerGroup().addTo(this.map)
    if (this.mapTarget.offsetWidth > 0) this.frame(this.matching())
    else { this.map.setView([0, 0], 2); this.unframed = true } // drawn while hidden (a phone's list view): framed when first seen
    // Moving the map changes the cards; zooming also regroups the pins (not on every move: an open popup's own pan would close it)
    this.map.on("moveend", () => this.refresh())
    this.map.on("zoomend", () => this.group(this.matching()))
  }

  // Fit the map to the places that hold most of the records (nine in ten): a few strays a long way off (a place filed under one region
  // but found in another) do not pull the map out to the whole world
  frame(places) {
    const sorted = [...places].sort((a, b) => b.count - a.count)
    const total = sorted.reduce((sum, place) => sum + place.count, 0)
    let running = 0
    const core = sorted.filter((place) => { const keep = running < total * 0.9; running += place.count; return keep })
    const points = core.map((place) => [place.lat, place.lon])
    if (!points.length) return this.map.setView([0, 0], this.map.getMinZoom())
    // On a small map the places may not fit even at the widest zoom: then the place with the most records is in the middle
    const bounds = this.L.latLngBounds(points)
    const widest = this.map.getMinZoom()
    const room = this.map.getSize().subtract([64, 64])
    const span = this.map.project(bounds.getSouthEast(), widest).subtract(this.map.project(bounds.getNorthWest(), widest))
    if (span.x > room.x || span.y > room.y) this.map.setView(points[0], widest)
    else this.map.fitBounds(bounds, { padding: [32, 32], maxZoom: 6 })
  }

  // Greedy grouping on screen pixels at the current zoom, the places with the most records first
  group(places) {
    const zoom = this.map.getZoom()
    const groups = []
    for (const place of [...places].sort((a, b) => b.count - a.count)) {
      const point = this.map.project([place.lat, place.lon], zoom)
      const near = groups.find((group) => group.point.distanceTo(point) < GROUP_PIXELS)
      if (near) near.members.push(place)
      else groups.push({ point, members: [place] })
    }
    this.layer.clearLayers()
    this.pins.clear()
    for (const group of groups) {
      const pin = group.members.length === 1 ? this.place(group.members[0]) : this.cluster(group)
      group.members.forEach((place) => this.pins.set(String(place.key), pin))
      this.layer.addLayer(pin)
    }
  }

  place(place) {
    const L = this.L
    const name = `${place.label}: ${this.records(place.count)}`
    const icon = L.divIcon({ className: "explore-map__pin", html: this.badge(place.count), iconSize: null })
    const pin = L.marker([place.lat, place.lon], { icon, keyboard: true, title: name })
    pin.bindPopup(() => this.popup(place), { className: "place-explorer__popup", minWidth: 200, maxWidth: 240 })
    // The popup's link takes the focus, and the pin gets it back when the popup closes (Escape, or its close button)
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
    const total = group.members.reduce((sum, place) => sum + place.count, 0)
    const name = this.word("group", { count: group.members.length.toLocaleString("en-AU"), records: this.records(total) })
    const icon = L.divIcon({ className: "explore-map__pin explore-map__pin--group", html: this.badge(total), iconSize: null })
    const bounds = L.latLngBounds(group.members.map((place) => [place.lat, place.lon]))
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
    span.textContent = count.toLocaleString("en-AU") // the same figure as in the pin's name, so the name holds the visible text
    return span.outerHTML
  }

  // A small card: the place's picture (when it has one), its name, where it is, and the way to it
  popup(place) {
    const box = document.createElement("div")
    box.className = "place-explorer__pop"
    if (place.image) {
      const image = document.createElement("img")
      image.src = place.image
      image.alt = ""
      image.className = "place-explorer__pop-image"
      box.append(image)
    }
    const heading = document.createElement("p")
    heading.className = "explore-map__popup-title"
    heading.textContent = place.label
    box.append(heading)
    if (place.where) {
      const where = document.createElement("p")
      where.className = "place-explorer__pop-where"
      where.textContent = place.where
      box.append(where)
    }
    const link = document.createElement("a")
    link.href = place.href
    link.textContent = place.card ? this.word("explore", { place: place.label }) : this.word("see_records", { records: this.records(place.count), place: place.label })
    if (place.card) {
      const count = document.createElement("p")
      count.className = "place-explorer__pop-where"
      count.textContent = this.records(place.count)
      box.append(count)
    }
    box.append(link)
    return box
  }

  // ---- small things

  records(count) {
    return this.word(count === 1 ? "record_one" : "record_other", { count: count.toLocaleString("en-AU") })
  }

  word(key, values = {}) {
    return Object.entries(values).reduce((text, [name, value]) => text.replace(`%{${name}}`, value), this.words[key] || "")
  }

  remembered() {
    try { return window.localStorage.getItem(REMEMBER) === "shown" } catch { return false }
  }

  remember(shown) {
    try {
      if (shown) window.localStorage.setItem(REMEMBER, "shown")
      else window.localStorage.removeItem(REMEMBER)
    } catch { /* private window or blocked storage: the map is simply not remembered */ }
  }
}
