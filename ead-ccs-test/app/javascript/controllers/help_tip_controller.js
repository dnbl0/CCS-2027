import { Controller } from "@hotwired/stimulus"

// A toggletip (CCS-101): the button shows and hides its note. Escape closes it and puts focus back on the button; so
// does moving focus out of the tip altogether (the note holds a link, so focus may move into it and stay open). The note
// is real text, in the page from the start, hidden until asked for. See components/nexus_ccs/help_tip_component.rb.
export default class extends Controller {
  static targets = [ "button", "panel" ]

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

  escape(event) {
    if (event.key !== "Escape" || this.panelTarget.hidden) return
    event.stopPropagation()
    this.close()
    this.buttonTarget.focus()
  }

  focusout(event) {
    if (!this.element.contains(event.relatedTarget)) this.close()
  }
}
