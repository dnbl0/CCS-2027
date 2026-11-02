import { Controller } from "@hotwired/stimulus"

// Keeps the filter sidebar steady while a filter changes the results (CCS-212). A filter is a link, so the page is
// replaced; without this the open filters close, focus drops to the top of the page and nothing is said.
// On the click it notes which filters are open and which one was used (sessionStorage, for the next page only); on the
// next page it opens the same filters, puts focus back on the filter that was used, and says how many results and filters
// apply in the polite status. A page that was not reached by a filter (a first visit, Back) is left as it is.
const KEY = "ccs.filters.change"
const MOBILE = "(max-width: 991.98px)"

export default class extends Controller {
  static targets = ["status"]
  static values = { message: String }

  connect() {
    const change = this.take()
    if (!change) return
    this.reopen(change.open)
    this.restoreFocus(change.used)
    // The status is empty in the page; text added after the page shows is what a screen reader announces. Focus is set
    // again then, in case Turbo's own page change (or the page loader coming off) took it.
    setTimeout(() => {
      this.statusTarget.textContent = this.messageValue
      if (!this.element.contains(document.activeElement)) this.restoreFocus(change.used)
    }, 150)
  }

  remember(event) {
    const link = event.target.closest("a[href]")
    if (!link || link.matches("[data-blacklight-modal]")) return // "Show more" opens a modal, it does not change the results
    const used = link.closest(".facet-limit")?.querySelector(".panel-collapse")?.id
    const open = [...this.element.querySelectorAll(".accordion-button[aria-expanded=true]")].map((b) => b.getAttribute("aria-controls"))
    try { sessionStorage.setItem(KEY, JSON.stringify({ open, used })) } catch (_) { /* storage blocked: the page just starts closed */ }
  }

  take() {
    try {
      const raw = sessionStorage.getItem(KEY)
      sessionStorage.removeItem(KEY)
      return raw ? JSON.parse(raw) : null
    } catch (_) { return null }
  }

  reopen(ids) {
    ids.forEach((id) => {
      const panel = document.getElementById(id)
      const button = this.element.querySelector(`.accordion-button[aria-controls="${CSS.escape(id)}"]`)
      if (!panel || !button) return
      panel.classList.add("show")
      button.classList.remove("collapsed")
      button.setAttribute("aria-expanded", "true")
    })
  }

  // The filter that was used, or its heading button when it has gone; in the phone drawer (closed again by the page change)
  // the Filters button, since nothing in a closed drawer can take focus.
  restoreFocus(used) {
    if (window.matchMedia(MOBILE).matches) return document.querySelector(".filters-toggle")?.focus()
    const button = (used && this.element.querySelector(`.accordion-button[aria-controls="${CSS.escape(used)}"]`)) ||
      this.element.querySelector(".filter-sidebar__clear, .accordion-button")
    button?.focus()
  }
}
