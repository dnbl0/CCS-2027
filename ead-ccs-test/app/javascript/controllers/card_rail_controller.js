import { Controller } from "@hotwired/stimulus"

// A row of cards that scrolls sideways (NexusCcs::CardLayoutComponent, layout rail): the previous and next buttons move it by most of its
// width, and each is shown only when there is more to scroll to that way. Without JavaScript the row still scrolls and takes the keyboard
// (it is focusable), and the buttons stay hidden.
export default class extends Controller {
  static targets = ["scroller", "previous", "next"]

  connect() {
    this.update = this.update.bind(this)
    this.scrollerTarget.addEventListener("scroll", this.update, { passive: true })
    this.resizer = new ResizeObserver(this.update)
    this.resizer.observe(this.scrollerTarget)
    this.update()
  }

  disconnect() {
    this.scrollerTarget.removeEventListener("scroll", this.update)
    this.resizer?.disconnect()
  }

  previous() { this.move(-1) }

  next() { this.move(1) }

  move(direction) {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.scrollerTarget.scrollBy({ left: direction * this.scrollerTarget.clientWidth * 0.85, behavior: reduce ? "auto" : "smooth" })
  }

  update() {
    const { scrollLeft, scrollWidth, clientWidth } = this.scrollerTarget
    this.show(this.previousTarget, scrollLeft > 1)
    this.show(this.nextTarget, scrollLeft + clientWidth < scrollWidth - 1)
  }

  // A button that has the keyboard focus is not hidden from under it: the focus moves to the row first, so the visitor keeps their place
  show(button, visible) {
    if (!visible && document.activeElement === button) this.scrollerTarget.focus()
    button.hidden = !visible
  }
}
