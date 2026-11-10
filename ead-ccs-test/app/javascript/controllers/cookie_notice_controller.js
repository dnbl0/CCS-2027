import { Controller } from "@hotwired/stimulus"

// The cookie notice (NexusCcs::CookieNoticeComponent). Without JavaScript the form posts and the page reloads. With it, the
// answer is posted in the background, the notice is removed and focus goes to the main content (the focused button is
// leaving the page, and focus left on <body> would start the visitor again at the top). Not a dialog: nothing is trapped, and
// nothing takes focus when the page loads. If the post fails, the form is submitted the ordinary way.
export default class extends Controller {
  async save(event) {
    if (this.plain) return // second pass: let the browser submit the form itself

    event.preventDefault()
    const form = event.target
    const submitter = event.submitter
    const body = new FormData(form)
    if (submitter && submitter.name) body.set(submitter.name, submitter.value)

    try {
      const response = await fetch(form.action, { method: "POST", body, headers: { Accept: "application/json" }, credentials: "same-origin" })
      if (!response.ok) throw new Error(response.status)
      this.dismiss()
    } catch (_) {
      this.plain = true
      form.requestSubmit(submitter)
    }
  }

  dismiss() {
    const main = document.querySelector("main")
    if (main) {
      if (!main.hasAttribute("tabindex")) main.setAttribute("tabindex", "-1")
      main.focus({ preventScroll: true })
    }
    this.element.remove()
  }
}
