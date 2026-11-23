import { Controller } from "@hotwired/stimulus"

// Justified rows (components/home_sections.css .justified): every card is as wide as its picture's shape at the row's height, so each
// picture shows whole and the rows fill the width. The shape comes from the server (--a on the item) when the picture's size is known;
// otherwise from the img's width and height attributes, or from the picture itself once it has loaded (the DAM's pictures). Without
// JavaScript an unknown shape stays at the fallback and the picture is fitted inside its card, never cropped.
export default class extends Controller {
  // The last row stretches to the full width when it is at least this full; a shorter one keeps the row height (as the wireframe's justify)
  static FILL = 0.6

  connect() {
    this.width = 0
    this.resizer = new ResizeObserver(() => { if (this.element.clientWidth !== this.width) this.fit() })
    this.resizer.observe(this.element)
    this.items().forEach((item) => {
      if (item.style.getPropertyValue("--a")) return
      const img = item.querySelector("img")
      if (!img) return
      const fromAttributes = Number(img.getAttribute("width")) / Number(img.getAttribute("height"))
      if (Number.isFinite(fromAttributes) && fromAttributes > 0) return this.set(item, fromAttributes)
      if (img.complete && img.naturalWidth) return this.set(item, img.naturalWidth / img.naturalHeight)
      img.addEventListener("load", () => this.set(item, img.naturalWidth / img.naturalHeight), { once: true })
    })
  }

  disconnect() { this.resizer?.disconnect() }

  // Measured with the spacer in place (the last row at its row height): how much of the width the last row's cards use
  fit() {
    this.width = this.element.clientWidth
    this.element.classList.remove("justified--fill")
    const items = this.items()
    if (!items.length || !this.width) return
    const top = items[items.length - 1].offsetTop
    const row = items.filter((item) => item.offsetTop === top)
    const gap = parseFloat(getComputedStyle(this.element).columnGap) || 0
    const used = row.reduce((total, item) => total + item.getBoundingClientRect().width, 0) + gap * (row.length - 1)
    this.element.classList.toggle("justified--fill", used / this.width >= this.constructor.FILL)
  }

  items() { return [ ...this.element.children ].filter((child) => child.tagName === "LI") }

  // A very tall or very wide picture is held to a sensible range, so no card is a sliver or fills a row on its own
  set(item, ratio) {
    if (ratio > 0) item.style.setProperty("--a", Math.min(2.6, Math.max(0.5, ratio)).toFixed(3))
    this.fit()
  }
}
