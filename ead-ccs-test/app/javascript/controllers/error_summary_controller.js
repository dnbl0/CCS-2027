import { Controller } from "@hotwired/stimulus"

// The error summary at the top of a form: a link in it moves focus to its field (a plain #fragment link only scrolls
// to the field and leaves keyboard focus in the summary). The summary itself takes focus from its autofocus attribute.
export default class extends Controller {
  focusField(event) {
    const link = event.target.closest("a[href^='#']")
    const field = link && document.getElementById(link.getAttribute("href").slice(1))
    if (!field) return

    event.preventDefault()
    field.scrollIntoView({ block: "center" })
    field.focus()
  }
}
