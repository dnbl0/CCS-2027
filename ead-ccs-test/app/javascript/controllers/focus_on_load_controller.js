import { Controller } from "@hotwired/stimulus"

// Moves focus to its element when the page shows (after a list is deleted or renamed, or a form has errors), so the
// keyboard and screen reader user lands on the result instead of at the top of the page. The element has tabindex="-1".
export default class extends Controller {
  connect() {
    this.element.focus({ preventScroll: false })
  }
}
