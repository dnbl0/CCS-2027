import { Controller } from "@hotwired/stimulus"

// A fluid mosaic without holes (components/home_sections.css .mosaic-flow; the homepage redesign after Google Arts & Culture's mixed
// layouts, 2026-11): lane masonry. The list has a number of equal lanes (lanesValue on a wide screen, fewer as it narrows, one on a phone);
// each tile, in order, goes into the shortest lane, so the reading order runs from the top left and no tile leaves a gap under another.
// The lead takes two lanes, and so does a wide picture where two lanes are nearly level. Where a lane ends short, its last tile's picture
// mount grows (the picture stays whole, centred on its pale mount), so the mosaic ends level instead of ragged. No picture is cropped.
// Each picture's shape (--a, width over height) comes from the server or is measured here once it loads.
// Without JavaScript the list is an even grid of the same cards.
export default class extends Controller {
  // ordered: the tiles are placed in their own order (a sequence: centuries), never rearranged to level the lanes; each still goes into the
  // shortest lane, so the order reads left to right, top to bottom
  static values = { lanes: { type: Number, default: 4 }, ordered: { type: Boolean, default: false } }
  static MIN_LANE = 208 // px: a lane is never narrower than this (13rem)
  static LEVEL = 48 // px: two lanes this close are level enough for a two-lane tile (the shorter one's last tile grows to meet it)

  connect() {
    this.measureShapes()
    this.resizer = new ResizeObserver(() => this.schedule())
    this.resizer.observe(this.element)
    this.schedule()
  }

  disconnect() { this.resizer?.disconnect(); cancelAnimationFrame(this.frame) }

  // The tiles shown: a list that narrows (Explore by place's cards) hides the others, and the mosaic is laid out again (mosaic:refresh)
  items() { return [ ...this.element.children ].filter((child) => child.tagName === "LI" && !child.hidden) }

  // A shape the server did not know: from the img's size attributes, or from the picture once it has loaded (the DAM's pictures)
  measureShapes() {
    this.items().forEach((item) => {
      if (item.style.getPropertyValue("--a")) return
      const img = item.querySelector("img")
      if (!img) return
      const fromAttributes = Number(img.getAttribute("width")) / Number(img.getAttribute("height"))
      if (Number.isFinite(fromAttributes) && fromAttributes > 0) return this.setShape(item, fromAttributes)
      if (img.complete && img.naturalWidth) return this.setShape(item, img.naturalWidth / img.naturalHeight)
      img.addEventListener("load", () => { this.setShape(item, img.naturalWidth / img.naturalHeight); this.schedule() }, { once: true })
    })
  }

  setShape(item, ratio) { if (ratio > 0) item.style.setProperty("--a", Math.min(2.6, Math.max(0.5, ratio)).toFixed(3)) }

  schedule() { cancelAnimationFrame(this.frame); this.frame = requestAnimationFrame(() => this.layout()) }

  static MAX_ROW = 352 // px: a short row's pictures are never taller than this (22rem), so two or three cards do not tower

  // A few tiles (no more than the lanes): one justified row. Each tile is as wide as its picture's shape at the row's height, so the
  // pictures share one height and the row fills the width; the cards are then made one height, so the row ends level.
  row(items, width, gap) {
    const shapes = items.map((item) => parseFloat(item.style.getPropertyValue("--a")) || 1.333)
    const total = shapes.reduce((sum, shape) => sum + shape, 0)
    const pictureHeight = Math.min(this.constructor.MAX_ROW, (width - gap * (items.length - 1)) / total)
    let left = 0
    items.forEach((item, i) => {
      const mount = this.mount(item)
      if (mount) mount.style.height = ""
      item.style.width = `${shapes[i] * pictureHeight}px`
      item.style.left = `${left}px`
      item.style.top = "0px"
      left += shapes[i] * pictureHeight + gap
    })
    const tallest = Math.max(...items.map((item) => item.getBoundingClientRect().height))
    items.forEach((item) => { (item.firstElementChild || item).style.minHeight = `${tallest}px` })
    this.element.style.height = `${tallest}px`
  }

  mount(item) { return item.querySelector(".result-card__media, .object-card__media") }

  // The lead first (where there is one), then the rest tallest first: a tile's height at a lane's width, its picture by its shape and its text
  tallestFirst(items, laneWidth) {
    const height = (item) => {
      const mount = this.mount(item)
      const text = item.getBoundingClientRect().height - (mount ? mount.getBoundingClientRect().height : 0)
      return laneWidth / (parseFloat(item.style.getPropertyValue("--a")) || 1.333) + text
    }
    const [first, ...rest] = items
    const lead = first?.classList.contains("mosaic-flow__item--lead")
    const sorted = (lead ? rest : items).map((item) => [item, height(item)]).sort((a, b) => b[1] - a[1]).map(([item]) => item)
    return lead ? [first, ...sorted] : sorted
  }

  // A short mosaic (under three rows of lanes, no lead): justified rows, as a photo wall. The tiles, in order, are shared among as many rows
  // as their pictures fill at about a lane's usual height, each row taking about the same total width, so every row is full; a row's
  // pictures then share the one height that makes it exactly as wide as the list (each whole), and its cards are made one height. Few tiles
  // in many lanes would otherwise end raggedly, with holes under the short lanes. A card is never narrower than NARROWEST times its row's
  // height (a tall, thin picture stands whole on its mount, with room for its name), and rows are never so many to a line that a row is
  // shorter than a NARROWEST card 11rem wide would allow.
  static NARROWEST = 0.75
  static NARROWEST_CARD = 176 // px

  rows(items, width, gap, laneWidth) {
    const usual = laneWidth / 1.15
    const shapes = items.map((item) => Math.max(this.constructor.NARROWEST, parseFloat(item.style.getPropertyValue("--a")) || 1.333))
    const total = shapes.reduce((sum, shape) => sum + shape, 0)
    const lowest = this.constructor.NARROWEST_CARD / this.constructor.NARROWEST // the shortest row that leaves every card room
    const count = Math.max(1, Math.min(items.length, Math.max(Math.round((total * usual) / width), Math.ceil((total * lowest) / width))))
    // break where the running width passes each row's share (never leaving a row empty)
    const rows = Array.from({ length: count }, () => [])
    let running = 0
    items.forEach((item, i) => {
      const r = Math.min(count - 1, Math.floor((running + shapes[i] / 2) / (total / count)))
      rows[Math.max(r, rows.findLastIndex((row) => row.length))].push({ item, shape: shapes[i] })
      running += shapes[i]
    })
    let top = 0
    rows.filter((row) => row.length).forEach((row) => {
      const sum = row.reduce((s, { shape }) => s + shape, 0)
      const height = Math.min((width - gap * (row.length - 1)) / sum, usual * 1.6) // one wide row on its own does not tower
      let left = 0
      row.forEach(({ item, shape }) => {
        const mount = this.mount(item)
        if (mount) mount.style.height = `${height}px` // the row's one picture height, whatever the card's width
        if (item.firstElementChild) item.firstElementChild.style.minHeight = ""
        item.style.width = `${shape * height}px`
        item.style.left = `${left}px`
        item.style.top = `${top}px`
        left += shape * height + gap
      })
      const tallest = Math.max(...row.map(({ item }) => item.getBoundingClientRect().height))
      row.forEach(({ item }) => { (item.firstElementChild || item).style.minHeight = `${tallest}px` })
      top += tallest + gap
    })
    this.element.style.height = `${Math.max(0, top - gap)}px`
  }

  layout() {
    const width = this.element.clientWidth
    if (!width) return
    const gap = parseFloat(getComputedStyle(this.element).columnGap) || 16
    const fit = Math.floor((width + gap) / (this.constructor.MIN_LANE + gap))
    const items = this.items()
    const lanes = Math.max(1, Math.min(this.lanesValue, fit))
    const laneWidth = (width - gap * (lanes - 1)) / lanes
    this.element.classList.add("is-ready")
    if (!items.length) { this.element.style.height = "0px"; return }
    // a mosaic with a lead (every section of the home page) is always lanes, however few its tiles, so the sections share one layout
    const lead = items.some((item) => item.classList.contains("mosaic-flow__item--lead"))
    if (!lead && items.length <= lanes) return this.row(items, width, gap)
    if (!lead && lanes > 1 && items.length < lanes * 3) return this.rows(items, width, gap, laneWidth)

    // A short mosaic (under three rows): after its lead, the tallest tiles go first, so the short ones fill in at the foot and the lanes end
    // nearly level (the longest-first rule for packing lanes; an ordered one keeps its order); its last pictures may grow by up to their own
    // height to level them
    const short = items.length < lanes * 3
    const placed = short && !this.orderedValue ? this.tallestFirst(items, laneWidth) : items
    const heights = new Array(lanes).fill(0)
    const spans = new Map() // each tile's lanes
    const last = new Array(lanes).fill(null) // the last tile in each lane, to grow when the lane ends short
    const grow = (item, by) => {
      const mount = this.mount(item)
      if (!mount || by <= 0) return false
      mount.style.height = `${mount.getBoundingClientRect().height + by}px`
      last.forEach((tile, c) => { if (tile === item) heights[c] += by }) // every lane it spans is now longer
      return true
    }

    placed.forEach((item) => {
      const mount = this.mount(item)
      if (mount) mount.style.height = "" // its own shape again before measuring
      if (item.firstElementChild) item.firstElementChild.style.minHeight = ""
      const shape = parseFloat(item.style.getPropertyValue("--a")) || 1.333
      const lead = item.classList.contains("mosaic-flow__item--lead")
      // the lead takes two lanes unless its picture is tall (a two-lane portrait would tower over the rest); a wide picture too, on 4+ lanes
      let span = lanes >= 3 && ((lead && shape >= 0.9) || (shape >= 1.7 && lanes >= 4)) ? 2 : 1

      // a two-lane tile goes only where two lanes are nearly level (the lowest such pair); otherwise it takes one lane
      let lane = 0
      if (span === 2) {
        let best = -1, bestTop = Infinity
        for (let c = 0; c < lanes - 1; c++) {
          if (Math.abs(heights[c] - heights[c + 1]) > this.constructor.LEVEL) continue
          const top = Math.max(heights[c], heights[c + 1])
          if (top < bestTop) { bestTop = top; best = c }
        }
        if (best < 0) span = 1
        else lane = best
      }
      if (span === 1) lane = heights.indexOf(Math.min(...heights))

      const top = Math.max(...heights.slice(lane, lane + span))
      for (let c = lane; c < lane + span; c++) { // level the shorter lane under it: its last tile grows
        if (heights[c] < top && last[c]) grow(last[c], top - heights[c])
      }

      item.style.width = `${laneWidth * span + gap * (span - 1)}px`
      item.style.left = `${lane * (laneWidth + gap)}px`
      item.style.top = `${top}px`
      const height = item.getBoundingClientRect().height
      spans.set(item, Array.from({ length: span }, (_, k) => lane + k))
      for (let c = lane; c < lane + span; c++) { heights[c] = top + height + gap; last[c] = item }
    })

    // End level: a lane that ends short grows its last tile's mount, when that is at most half again its picture's height, and only a
    // tile that is the last in every lane it spans (growing one with a tile under it in another lane would run into that tile)
    const bottom = Math.max(...heights)
    const grown = new Map()
    heights.forEach((h, c) => {
      const item = last[c]
      if (!item || h >= bottom) return
      const lanesOf = spans.get(item) || []
      if (lanesOf.every((x) => last[x] === item)) grown.set(item, Math.max(grown.get(item) || 0, bottom - h))
    })
    grown.forEach((by, item) => {
      const mount = this.mount(item)
      if (mount && by <= mount.getBoundingClientRect().height * (short ? 1 : 0.5)) grow(item, by)
    })
    this.element.style.height = `${Math.max(0, ...items.map((item) => item.offsetTop + item.offsetHeight))}px`
  }
}
