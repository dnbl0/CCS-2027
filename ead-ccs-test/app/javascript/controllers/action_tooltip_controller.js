import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"

// A tooltip for each icon-only button inside it, saying what the button does (its text is the button's
// data-action-tooltip-text). Built to WCAG 1.4.13: it shows on hover and on keyboard focus, stays while the pointer
// is over it, goes with Escape, and never times out. Bootstrap draws it (role="tooltip", aria-describedby on the
// button while it shows) in <body>, so the table's horizontal scroll box cannot clip it. The button keeps its own
// accessible name from its visually hidden text; the tooltip is extra, not the name.
export default class extends Controller {
  connect() {
    this.hideTimers = new Map()
    this.buttons = [...this.element.querySelectorAll("[data-action-tooltip-text]")]
    this.handlers = this.buttons.map((button) => {
      const tooltip = new bootstrap.Tooltip(button, {
        title: button.dataset.actionTooltipText, trigger: "manual", container: "body", placement: "top", fallbackPlacements: [ "bottom" ]
      })
      const show = () => this.show(button, tooltip)
      const hide = () => this.hideSoon(button, tooltip)
      button.addEventListener("mouseenter", show)
      button.addEventListener("focus", show)
      button.addEventListener("mouseleave", hide)
      button.addEventListener("blur", () => this.hideNow(button, tooltip))
      // As soon as the tooltip is in the page (not after its fade), so a pointer that moves straight onto it keeps it
      button.addEventListener("inserted.bs.tooltip", () => {
        tooltip.tip.addEventListener("mouseenter", () => this.cancelHide(button))
        tooltip.tip.addEventListener("mouseleave", hide)
      })
      return { button, tooltip }
    })
    this.onEscape = (event) => { if (event.key === "Escape") this.handlers.forEach(({ button, tooltip }) => this.hideNow(button, tooltip)) }
    document.addEventListener("keydown", this.onEscape)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onEscape)
    this.hideTimers.forEach((timer) => clearTimeout(timer))
    this.handlers.forEach(({ tooltip }) => tooltip.dispose())
  }

  show(button, tooltip) {
    this.cancelHide(button)
    tooltip.show()
  }

  // A short delay lets the pointer cross the gap from the button to the tooltip without it closing
  hideSoon(button, tooltip) {
    this.cancelHide(button)
    this.hideTimers.set(button, setTimeout(() => tooltip.hide(), 150))
  }

  hideNow(button, tooltip) {
    this.cancelHide(button)
    tooltip.hide()
  }

  cancelHide(button) {
    clearTimeout(this.hideTimers.get(button))
  }
}
