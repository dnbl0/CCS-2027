import { Controller } from "@hotwired/stimulus"

// The Web Share sheet, where the browser has one (phones and some desktops): the button is hidden until then, so a browser
// without it shows only Copy link. Nothing is sent anywhere by the site; the visitor's device offers the choices.
export default class extends Controller {
  static targets = ["button"]
  static values = { title: String, url: String }

  connect() {
    if (typeof navigator.share === "function") this.buttonTarget.hidden = false
  }

  async share() {
    try {
      await navigator.share({ title: this.titleValue, url: this.urlValue })
    } catch (error) {
      // closing the sheet is not a failure; the visitor still has Copy link
      if (error.name !== "AbortError") console.warn("Sharing failed", error)
    }
  }
}
