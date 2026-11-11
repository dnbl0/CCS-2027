import { Controller } from "@hotwired/stimulus"

// A card whose thumbnail file is missing or fails to load drops the image and becomes its no-image variant, so the page never shows a
// broken-image box. The record card also reveals its kicker (the text card's first line). The check on connect covers an image that
// failed before the script ran. Values: remove-class and add-class swap the card's media class for its no-image class.
export default class extends Controller {
  static targets = [ "media", "kicker" ]
  static values = { removeClass: String, addClass: String }

  connect() {
    const image = this.hasMediaTarget ? this.mediaTarget.querySelector("img") : null
    if (image && image.complete && image.naturalWidth === 0) this.failed()
  }

  failed() {
    if (this.hasMediaTarget) this.mediaTarget.remove()
    if (this.hasKickerTarget) this.kickerTarget.hidden = false
    if (this.hasRemoveClassValue && this.removeClassValue) this.element.classList.remove(this.removeClassValue)
    if (this.hasAddClassValue && this.addClassValue) this.element.classList.add(this.addClassValue)
  }
}
