import { Controller } from "@hotwired/stimulus"

// The record page's full record (RecordDocumentComponent): open from 1024px, closed on a smaller screen, where the Key facts above
// it are enough to start with. Decided once, when the page opens, so a visitor's own opening or closing is never undone. Without
// JavaScript it stays open.
export default class extends Controller {
  connect() {
    if (!window.matchMedia("(min-width: 64rem)").matches) this.element.open = false
  }
}
