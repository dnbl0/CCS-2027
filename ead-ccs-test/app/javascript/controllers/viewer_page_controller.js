import { Controller } from "@hotwired/stimulus"

// The viewer layout of the record page (?layout=viewer): the download button follows the image the hero shows, the cards of the
// highlights scroll with round chevron buttons (which are disabled at the ends), and a card opens its image in the hero viewer.
export default class extends Controller {
  static targets = [ "scroller", "back", "forward" ]

  connect() { this.sync() }

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
