import { Controller } from "@hotwired/stimulus"

// A record card whose thumbnail file is missing or fails to load drops the image and becomes the text card (kicker, title, creator and
// date), so the page never shows a broken-image box. The check on connect covers an image that failed before the script ran.
export default class extends Controller {
  static targets = [ "media", "kicker" ]

  connect() {
    const image = this.hasMediaTarget ? this.mediaTarget.querySelector("img") : null
    if (image && image.complete && image.naturalWidth === 0) this.failed()
  }

  failed() {
    if (this.hasMediaTarget) this.mediaTarget.remove()
    if (this.hasKickerTarget) this.kickerTarget.hidden = false
    this.element.classList.add("object-card--text")
  }
}
