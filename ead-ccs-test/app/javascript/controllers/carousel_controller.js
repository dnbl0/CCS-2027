import { Controller } from "@hotwired/stimulus"

// A carousel of slides in a row that scrolls sideways (FeatureCarouselComponent): the previous and next buttons move it one slide, and
// are marked disabled at its ends (aria-disabled, so a button the focus is on keeps it). Nothing moves on its own; the row also scrolls by touch, trackpad or moving the focus along it.
export default class extends Controller {
  static targets = ["track", "previous", "next"]

  connect() { this.update() }

  previous(event) { if (event.currentTarget.getAttribute("aria-disabled") !== "true") this.move(-1) }
  next(event) { if (event.currentTarget.getAttribute("aria-disabled") !== "true") this.move(1) }

  move(direction) {
    const slide = this.trackTarget.firstElementChild
    if (!slide) return
    const gap = parseFloat(getComputedStyle(this.trackTarget).columnGap) || 0
    const smooth = !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.trackTarget.scrollBy({ left: direction * (slide.offsetWidth + gap), behavior: smooth ? "smooth" : "auto" })
  }

  update() {
    const track = this.trackTarget
    const end = track.scrollWidth - track.clientWidth - 1
    this.previousTarget.setAttribute("aria-disabled", track.scrollLeft <= 1)
    this.nextTarget.setAttribute("aria-disabled", track.scrollLeft >= end)
  }
}
