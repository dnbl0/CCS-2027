import { Controller } from "@hotwired/stimulus"

// The viewer layout of the record page (?layout=viewer): the download button follows the image the hero shows, the cards of the
// highlights scroll with round chevron buttons (which are disabled at the ends), and a card opens its image in the hero viewer.
export default class extends Controller {
  static targets = [ "scroller", "back", "forward", "template" ]
  static values = { rows: Boolean }

  connect() {
    this.sync()
    if (this.rowsValue) this.watchRows()
  }

  disconnect() {
    this.observer?.disconnect()
    this.resizer?.disconnect()
  }

  // The rows of More like this (Related objects, Similar records, Recently viewed): from 1024px, when a row is wider than the page, two
  // round buttons under it scroll it. Similar records arrives later in a lazy frame, so the rows are looked for again as the page changes.
  watchRows() {
    if (!this.hasTemplateTarget) return
    this.resizer = new ResizeObserver(() => this.element.querySelectorAll("[data-row-bar]").forEach((bar) => bar.update()))
    this.attachRows()
    this.observer = new MutationObserver(() => this.attachRows())
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  attachRows() {
    this.element.querySelectorAll(".object-cards__list:not([data-chevrons])").forEach((list) => {
      list.dataset.chevrons = "true"
      const name = list.closest(".object-cards")?.querySelector(".object-cards__heading")?.textContent.trim() || ""
      const bar = this.templateTarget.content.firstElementChild.cloneNode(true)
      const [ back, forward ] = bar.querySelectorAll("button")
      ;[ back, forward ].forEach((button) => button.setAttribute("aria-label", button.getAttribute("aria-label").replace("%{row}", name)))
      bar.dataset.rowBar = "true"
      const reduced = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches
      const step = (direction) => list.scrollBy({ left: direction * list.clientWidth * 0.8, behavior: reduced() ? "auto" : "smooth" })
      bar.update = () => {
        bar.hidden = list.scrollWidth <= list.clientWidth + 1
        back.disabled = list.scrollLeft <= 1
        forward.disabled = list.scrollLeft + list.clientWidth >= list.scrollWidth - 1
      }
      back.addEventListener("click", () => step(-1))
      forward.addEventListener("click", () => step(1))
      list.addEventListener("scroll", bar.update, { passive: true })
      list.insertAdjacentElement("afterend", bar)
      this.resizer.observe(list)
      bar.update()
    })
  }

  // media-viewer:shown, from the hero: an open record's download links go to the image now shown
  shown(event) {
    const src = event.detail?.src
    if (!src) return
    this.element.querySelectorAll("[data-viewer-use]").forEach((link) => { link.href = src })
  }

  back() { this.move(-1) }
  forward() { this.move(1) }

  move(direction) {
    if (!this.hasScrollerTarget) return
    const scroller = this.scrollerTarget
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    scroller.scrollBy({ left: direction * scroller.clientWidth * 0.8, behavior: reduced ? "auto" : "smooth" })
  }

  sync() {
    if (!this.hasScrollerTarget || !this.hasBackTarget) return
    const scroller = this.scrollerTarget
    this.backTarget.disabled = scroller.scrollLeft <= 1
    this.forwardTarget.disabled = scroller.scrollLeft + scroller.clientWidth >= scroller.scrollWidth - 1
  }

  // A card shows its picture in the hero viewer, scrolls the hero into view and moves focus to the picture
  openImage(event) {
    const index = event.params.index
    const thumb = this.element.querySelectorAll(".viewer-dots .viewer-media__thumb")[index]
    thumb?.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))
    const hero = this.element.querySelector(".viewer-hero")
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    hero?.scrollIntoView({ block: "start", behavior: reduced ? "auto" : "smooth" })
    const target = this.element.querySelector(".viewer-media__figure .openseadragon-canvas") || this.element.querySelector(".viewer-media__figure")
    target?.focus({ preventScroll: true })
  }
}
