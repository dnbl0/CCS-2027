import { Controller } from "@hotwired/stimulus"

// A link to a folding section (<details>) on the same page: opens it, moves focus to its summary and scrolls it into view. A closed
// <details> does not open when its id is the target of a link, so without this the link would land on a closed section.
// Without JavaScript the link still jumps to the section.
export default class extends Controller {
  open(event) {
    const id = this.element.getAttribute("href")?.slice(1)
    const details = id && document.getElementById(id)
    if (!(details instanceof HTMLDetailsElement)) return
    event.preventDefault()
    details.open = true
    const summary = details.querySelector("summary")
    summary?.focus({ preventScroll: true })
    details.scrollIntoView({ block: "start", behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" })
    history.replaceState(null, "", `#${id}`)
  }
}
