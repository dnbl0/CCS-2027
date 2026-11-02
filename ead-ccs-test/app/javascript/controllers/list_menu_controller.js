import { Controller } from "@hotwired/stimulus"

// The "Add to list" disclosure on a record (NexusCcs::AddToListComponent): a button that shows or hides the panel of
// lists. The page works without JavaScript (the panel is simply open and the button hidden), so this reveals the button
// and closes the panel. Focus stays on the button when it is activated; Escape or a click elsewhere closes the panel,
// and Escape puts focus back on the button.
export default class extends Controller {
  static targets = [ "button", "panel" ]

  connect() {
    this.buttonTarget.hidden = false
    this.close()
    this.onDocumentClick = (event) => { if (!this.element.contains(event.target)) this.close() }
    document.addEventListener("click", this.onDocumentClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
  }

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.panelTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  // Escape inside the panel or on the button
  escape(event) {
    if (event.key !== "Escape" || this.panelTarget.hidden) return
    this.close()
    this.buttonTarget.focus()
  }
}
