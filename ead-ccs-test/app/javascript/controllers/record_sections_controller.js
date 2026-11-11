import { Controller } from "@hotwired/stimulus"

// The record page's sections (Object details, Copyright and use, About this record) are <details> elements so that on a phone they
// are accordions: Object details open, the others closed. From 768px wide they are all open and fixed open (their summary is not
// a control), so the page reads as plain sections. Without JavaScript every section is open and each summary still works.
export default class extends Controller {
  static targets = [ "section" ]

  connect() {
    this.wide = window.matchMedia("(min-width: 48rem)")
    this.onChange = () => this.apply()
    this.onClick = (event) => { if (this.wide.matches) event.preventDefault() }
    this.wide.addEventListener("change", this.onChange)
    this.sectionTargets.forEach((section) => section.querySelector("summary")?.addEventListener("click", this.onClick))
    this.apply(true)
  }

  disconnect() {
    this.wide.removeEventListener("change", this.onChange)
    this.sectionTargets.forEach((section) => section.querySelector("summary")?.removeEventListener("click", this.onClick))
  }

  apply(first = false) {
    this.sectionTargets.forEach((section) => {
      const summary = section.querySelector("summary")
      if (this.wide.matches) {
        section.open = true
        summary?.setAttribute("tabindex", "-1")
        section.classList.add("is-fixed")
      } else {
        summary?.removeAttribute("tabindex")
        section.classList.remove("is-fixed")
        if (first && section.dataset.openOnPhone === undefined) section.open = false
      }
    })
  }
}
