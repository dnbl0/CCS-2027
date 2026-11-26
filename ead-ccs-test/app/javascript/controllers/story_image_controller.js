import { Controller } from "@hotwired/stimulus"

// A story card's picture comes from the collection's own website (CollectionStoriesComponent). That site may refuse to serve it
// (the University's sites answer some visitors with a "are you a robot" check), which would leave a broken-image icon in an empty
// grey frame. When the picture cannot load, the card becomes a text card (object-card--text), like a record card with no image.
// Without JavaScript the browser shows whatever it can.
export default class extends Controller {
  static targets = [ "media", "image" ]

  connect() {
    if (!this.hasImageTarget) return

    const image = this.imageTarget
    if (image.complete && image.naturalWidth === 0 && image.currentSrc) this.fail()
  }

  fail() {
    if (this.hasMediaTarget) this.mediaTarget.remove()
    this.element.classList.add("object-card--text")
  }
}
