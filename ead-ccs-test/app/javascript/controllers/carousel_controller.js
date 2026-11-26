import { Controller } from "@hotwired/stimulus"

// A carousel of slides in a row that scrolls sideways (CardCarouselComponent): the previous and next buttons
// move it one slide, and are marked disabled at its ends (aria-disabled, so a button the focus is on keeps it); where there is a status
// ("1 of 4", the card carousel's), it names the slide at the row's start; the left and right arrow keys move it from inside the row.
// Nothing moves on its own; the row also scrolls by touch, trackpad or moving the focus along it.
export default class extends Controller {
  static targets = ["track", "previous", "next", "status"]

  connect() { this.update() }

  previous(event) { if (event.currentTarget.getAttribute("aria-disabled") !== "true") this.move(-1) }
  next(event) { if (event.currentTarget.getAttribute("aria-disabled") !== "true") this.move(1) }

  key(event) {
    if (event.key === "ArrowRight") { event.preventDefault(); this.move(1) }
    if (event.key === "ArrowLeft") { event.preventDefault(); this.move(-1) }
  }

  step() {
    const slide = this.trackTarget.firstElementChild
    if (!slide) return 0
    return slide.offsetWidth + (parseFloat(getComputedStyle(this.trackTarget).columnGap) || 0)
  }

  move(direction) {
    const smooth = !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.trackTarget.scrollBy({ left: direction * this.step(), behavior: smooth ? "smooth" : "auto" })
  }

  update() {
    const track = this.trackTarget
    const end = track.scrollWidth - track.clientWidth - 1
    this.previousTarget.setAttribute("aria-disabled", track.scrollLeft <= 1)
    this.nextTarget.setAttribute("aria-disabled", track.scrollLeft >= end)
    if (this.hasStatusTarget) {
      const count = track.children.length
      const index = track.scrollLeft >= end ? count : Math.min(count, Math.round(track.scrollLeft / (this.step() || 1)) + 1)
      const words = `${index} of ${count}`
      if (this.statusTarget.textContent !== words) this.statusTarget.textContent = words // said only when it changes
    }
  }
}
