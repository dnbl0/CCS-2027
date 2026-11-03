import { Controller } from "@hotwired/stimulus"
import { inertOutside, releaseInert } from "modal_lock"

const PHONE = "(max-width: 1023px)"

// Site header behaviour: desktop dropdown panels and the mobile drawer. On mobile, opening a
// section "drills in": the section replaces the menu list and its name is shown under the
// home link, which stays visible and keeps its own name. While the drawer covers the page, everything outside the header is inert.
export default class extends Controller {
  static targets = ["nav", "menu", "menuLabel", "trigger", "title", "section"]

  connect() {
    this.phone = window.matchMedia(PHONE)
    this.leavePhone = () => { if (!this.phone.matches) this.setMenu(false) }
    this.phone.addEventListener("change", this.leavePhone)
  }

  disconnect() {
    this.phone.removeEventListener("change", this.leavePhone)
    releaseInert(this)
  }

  openSearch() {
    this.dispatch("open", { prefix: "search-overlay", bubbles: true })
  }

  toggleSection(event) {
    const trigger = event.currentTarget
    const wasOpen = trigger.getAttribute("aria-expanded") === "true"
    this.closeSections(trigger)
    trigger.setAttribute("aria-expanded", wasOpen ? "false" : "true")
    this.syncTitle()
    // The phone trigger is hidden while its section is open, so focus moves into the panel.
    if (!wasOpen && this.phone.matches) document.getElementById(trigger.getAttribute("aria-controls"))?.querySelector(".site-nav__back, a")?.focus()
  }

  back(event) {
    const panel = event.currentTarget.closest(".site-nav__panel")
    const trigger = this.triggerTargets.find((t) => t.getAttribute("aria-controls") === panel?.id)
    if (!trigger) return
    trigger.setAttribute("aria-expanded", "false")
    this.syncTitle()
    trigger.focus()
  }

  toggleMenu() {
    this.setMenu(this.menuTarget.getAttribute("aria-expanded") !== "true")
  }

  escape() {
    const open = this.openTrigger
    if (open) {
      this.closeSections()
      open.focus()
    } else if (this.menuOpen) {
      this.setMenu(false)
      this.menuTarget.focus()
    }
  }

  // A click outside an open dropdown closes it; outside the header it also closes the drawer.
  // A click on the dimmed page behind the drawer lands on the header itself.
  clickAway(event) {
    if (event.target === this.element) return this.setMenu(false)
    if (this.element.contains(event.target)) {
      if (!event.target.closest(".site-nav__panel, .site-nav__trigger, .site-header__menu")) this.closeSections()
      return
    }
    this.closeSections()
    this.setMenu(false)
  }

  // Keyboard users tabbing out of the header close the dropdown.
  focusAway(event) {
    if (!this.element.contains(event.target)) this.closeSections()
  }

  setMenu(open) {
    this.menuTarget.setAttribute("aria-expanded", String(open))
    this.menuLabelTarget.textContent = open ? "Close" : "Menu"
    this.navTarget.classList.toggle("is-open", open)
    if (open) inertOutside(this, this.element)
    else releaseInert(this)
    if (!open) this.closeSections()
  }

  closeSections(except = null) {
    this.triggerTargets.forEach((trigger) => {
      if (trigger !== except) trigger.setAttribute("aria-expanded", "false")
    })
    this.syncTitle()
  }

  syncTitle() {
    const open = this.openTrigger
    const drilledIn = Boolean(open) && window.matchMedia(PHONE).matches
    this.sectionTarget.textContent = drilledIn ? open.textContent.replace(/\s+/g, " ").trim() : ""
    this.sectionTarget.hidden = !drilledIn
  }

  get openTrigger() {
    return this.triggerTargets.find((trigger) => trigger.getAttribute("aria-expanded") === "true")
  }

  get menuOpen() {
    return this.menuTarget.getAttribute("aria-expanded") === "true"
  }
}
