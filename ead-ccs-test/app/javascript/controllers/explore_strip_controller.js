import { Controller } from "@hotwired/stimulus"

// The strip of an Explore page (Explore by colour's colours, Explore by time's centuries; after Google Arts & Culture's Color Explorer,
// which keeps the chosen colour in the middle of its strip). The strip and its wall are one Turbo frame, so this connects again each time
// a choice swaps them in:
// - where the strip is wider than the screen and scrolls sideways, the chosen item is scrolled to its middle (only the strip scrolls);
// - after a swap (the frame then has a src), the page's title follows the choice (titleValue), and focus goes back to the chosen item,
//   which the swap replaced: a keyboard or screen reader user stays where they were instead of being sent to the top of the page.
export default class extends Controller {
  static targets = ["chosen"]
  static values = { title: String }

  connect() {
    const swapped = this.element.closest("turbo-frame")?.hasAttribute("src")
    if (swapped && this.titleValue) document.title = this.titleValue
    if (!this.hasChosenTarget) return
    const list = this.element.querySelector(".explore-strip__list")
    const item = this.chosenTarget.parentElement
    list.scrollLeft = item.offsetLeft - (list.clientWidth - item.offsetWidth) / 2
    if (swapped && document.activeElement === document.body) this.chosenTarget.focus({ preventScroll: true })
  }
}
