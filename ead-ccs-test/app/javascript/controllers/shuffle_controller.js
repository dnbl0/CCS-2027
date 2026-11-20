import { Controller } from "@hotwired/stimulus"

// "You may also like" (similar/collage): six of the twelve similar records show at a time; Shuffle shows six others, picked at random
// from the rest, and says so to a screen reader. Without JavaScript the first six show and there is no button.
export default class extends Controller {
  static targets = [ "item", "button", "status" ]
  static values = { shown: { type: Number, default: 6 }, message: String }

  connect() {
    if (this.itemTargets.length > this.shownValue) this.buttonTarget.hidden = false
  }

  shuffle() {
    const visible = this.itemTargets.filter((item) => !item.hidden)
    const others = this.itemTargets.filter((item) => item.hidden)
    const pool = others.length >= this.shownValue ? others : others.concat(visible)
    const picked = pool.map((item) => [ Math.random(), item ]).sort((a, b) => a[0] - b[0]).slice(0, this.shownValue).map(([ , item ]) => item)
    this.itemTargets.forEach((item) => { item.hidden = !picked.includes(item) })
    this.statusTarget.textContent = this.messageValue
  }
}
