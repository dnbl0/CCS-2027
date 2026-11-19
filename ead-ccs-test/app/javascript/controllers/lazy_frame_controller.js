import { Controller } from "@hotwired/stimulus"

// A lazy section of the record page (Related objects, the panels of More from the collections): a Turbo frame filled when it nears
// the screen. An answer that holds no matching frame (an error page, a record no longer in the index) leaves the frame empty, where
// Turbo would otherwise show that page in place of the whole record page. A "no content" answer (204) shows the frame's empty
// message, when it has one (the element after it, [data-lazy-frame-empty]).
export default class extends Controller {
  missing(event) {
    event.preventDefault()
  }

  answered(event) {
    if (event.detail.fetchResponse?.statusCode !== 204) return
    const empty = this.element.nextElementSibling
    if (empty?.hasAttribute("data-lazy-frame-empty")) empty.hidden = false
  }
}
