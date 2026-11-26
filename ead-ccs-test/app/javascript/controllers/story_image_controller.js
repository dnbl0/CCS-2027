import { Controller } from "@hotwired/stimulus"

// A story's picture (CollectionStoriesComponent) comes from the collection's own website, which may refuse to serve it (the
// University's sites answer some visitors with an "are you a robot" check). Rather than a broken-image icon, the story then shows
// the record's own picture of the object (the fallback value) and, if that will not load either, becomes a text story.
// Without JavaScript the browser shows whatever it can.
export default class extends Controller {
  static targets = [ "media", "image" ]
  static values = { fallback: String }

  connect() {
    if (!this.hasImageTarget) return

    const image = this.imageTarget
    if (image.complete && image.naturalWidth === 0 && image.currentSrc) this.fail()
  }

  fail() {
    const image = this.imageTarget
    if (this.fallbackValue && image.getAttribute("src") !== this.fallbackValue) {
      image.src = this.fallbackValue
      return
    }

    if (this.hasMediaTarget) this.mediaTarget.remove()
    this.element.classList.add("story--text")
  }
}
