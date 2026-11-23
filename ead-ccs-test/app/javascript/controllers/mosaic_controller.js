import { Controller } from "@hotwired/stimulus"

// A fluid mosaic (components/home_sections.css .mosaic-flow; the homepage redesign after Google Arts & Culture's mixed-size layouts,
// 2026-11): tiles of different widths and heights interlock on a 12-column grid (8 on a tablet, 4 on a phone), and no picture is cropped.
// Each tile's width comes from its picture's shape (--a, width over height: a wide picture takes more columns, a tall one fewer; the lead
// takes more again) and its height follows from the picture and the words under it. Each tile, in order, goes where the columns it spans
// are lowest, so the reading order still runs from the top left. Without JavaScript the list is an even grid of the same cards.
const RHYTHM = [ 1, 1.15, 0.85, 1.1, 0.9, 1.2, 0.8 ]

export default class extends Controller {
  static values = { base: { type: Number, default: 4 } }
  static UNIT = 8 // px: the grid's row height; a tile spans as many rows as its height needs

  connect() {
    this.measureShapes()
    this.width = 0
    this.resizer = new ResizeObserver(() => this.schedule())
    this.resizer.observe(this.element)
    this.items().forEach((item) => this.resizer.observe(item.firstElementChild || item))
    this.schedule()
  }

  disconnect() { this.resizer?.disconnect(); cancelAnimationFrame(this.frame) }

  items() { return [ ...this.element.children ].filter((child) => child.tagName === "LI") }

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

  layout() {
    const width = this.element.clientWidth
    if (!width) return
    const cols = width >= 960 ? 12 : width >= 600 ? 8 : 4
    const gap = parseFloat(getComputedStyle(this.element).columnGap) || 16
    const unit = this.constructor.UNIT
    const items = this.items()
    this.element.style.setProperty("--cols", cols)
    this.element.classList.add("is-ready")

    // 1. each tile's columns, from its shape: the widths are then right to measure the heights
    const least = cols === 4 ? 4 : 2 // the narrowest tile, in columns (a phone: one tile to a row)
    const spans = items.map((item, i) => {
      const shape = parseFloat(item.style.getPropertyValue("--a")) || 1.333
      const lead = item.classList.contains("mosaic-flow__item--lead")
      const rhythm = lead ? 1.7 : RHYTHM[i % RHYTHM.length] // neighbours differ in width, so the tiles interlock
      let span = Math.round(this.baseValue * Math.sqrt(shape) * rhythm * cols / 12)
      if (lead) span = Math.min(span, Math.ceil(cols * 0.58)) // the lead is at most a little over half the width
      return Math.max(Math.min(cols, least), Math.min(cols, span))
    })
    items.forEach((item, i) => { item.style.gridColumn = `span ${spans[i]}`; item.style.gridRow = "auto" })

    // 2. place each, in order, at the lowest place it fits: a tile may narrow (to 70% of its width, not under the narrowest tile) to
    //    fit a gap beside an earlier one, and widens to take a strip beside it too narrow for another tile
    const heights = new Array(cols).fill(0)
    items.forEach((item, i) => {
      const want = spans[i]
      const smallest = Math.min(want, Math.max(least, Math.round(want * 0.7)))
      let best = null
      for (let c = 0; c < cols; c++) {
        const top = heights[c]
        if (c > 0 && heights[c - 1] <= top) continue // a run starts where the column to its left is higher
        let run = 0
        while (c + run < cols && heights[c + run] <= top) run++
        if (run < smallest) continue
        let span = Math.min(want, run)
        if (run - span > 0 && run - span < least) span = run // no sliver left beside it
        if (!best || top < best.top) best = { c, top, span }
      }
      if (!best) { // nothing fits at a run's foot: under the lowest columns, at the width it wants
        let top = Infinity, c0 = 0
        for (let c = 0; c <= cols - want; c++) { const t = Math.max(...heights.slice(c, c + want)); if (t < top) { top = t; c0 = c } }
        best = { c: c0, top, span: want }
      }
      item.style.gridColumn = `span ${best.span}`
      const rows = Math.ceil(((item.firstElementChild || item).getBoundingClientRect().height + gap) / unit)
      item.style.gridColumn = `${best.c + 1} / span ${best.span}`
      item.style.gridRow = `${best.top + 1} / span ${rows}`
      for (let c = best.c; c < best.c + best.span; c++) heights[c] = best.top + rows
    })
  }
}
