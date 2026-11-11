import { Controller } from "@hotwired/stimulus"

// The home page's "Place and time" disclosures (details elements): closed on a phone, to keep the section short, and open from tablet
// width up, where there is room. The markup is closed; CSS already shows the content at the wide width (so nothing moves when this runs),
// and this sets the open state so assistive technology agrees with what is on screen. A visitor can still open or close either one.
const WIDE = "(min-width: 48rem)"

export default class extends Controller {
  connect() {
    this.query = window.matchMedia(WIDE)
    this.sync = () => { this.element.open = this.query.matches }
    this.sync()
    this.query.addEventListener("change", this.sync)
  }

  disconnect() {
    this.query.removeEventListener("change", this.sync)
  }
}
