import { Controller } from "@hotwired/stimulus"

// Explore by colour's strip (colours/index; after Google Arts & Culture's Color Explorer, which keeps the chosen colour in the middle of
// its strip): where the strip is wider than the screen and scrolls sideways (a phone), the chosen swatch is scrolled to its middle. Only
// the strip scrolls, never the page.
export default class extends Controller {
  static targets = ["chosen"]

  connect() {
    if (!this.hasChosenTarget) return
    const list = this.element.querySelector(".colour-strip__list")
    const swatch = this.chosenTarget.parentElement
    list.scrollLeft = swatch.offsetLeft - (list.clientWidth - swatch.offsetWidth) / 2
  }
}
