import { Controller } from "@hotwired/stimulus"

// A fanned stack of cards (NexusCcs::StackComponent, after Google Arts & Culture's "SimpleStack"). The fan itself is CSS
// (components/home_sections.css): each card keeps its place along the row; its size, depth and dimness follow its steps from the centre
// (data-away) and its side of it (data-side: pushed outward). Pointing at a card or giving it the focus makes it the centre: this only
// rewrites every card's steps and side.
export default class extends Controller {
  static targets = ["card"]

  point(event) {
    const centre = this.cardTargets.indexOf(event.currentTarget)
    if (centre < 0 || event.currentTarget.classList.contains("is-centre")) return
    this.cardTargets.forEach((card, index) => {
      card.dataset.away = String(Math.abs(index - centre))
      card.dataset.side = String(Math.sign(index - centre))
      card.classList.toggle("is-centre", index === centre)
    })
  }
}
