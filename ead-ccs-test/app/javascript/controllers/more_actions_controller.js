import { Controller } from "@hotwired/stimulus"

// More on the record page (NexusCcs::RecordActionsComponent): a menu button after the WAI-ARIA APG pattern. More opens the menu
// and focuses its first item; the arrow keys, Home and End move between items; Escape, Tab or a click elsewhere closes it, and
// Escape puts focus back on More. An item either opens a dialog by its id (Add to list, Cite this record: focus comes back to More
// when the dialog closes) or copies the record's link and says "Link copied" in a polite status line.
export default class extends Controller {
  static targets = [ "button", "menu", "item", "status" ]
  static values = { copied: String }

  connect() {
    this.element.hidden = false
    this.onDocumentClick = (event) => { if (!this.element.contains(event.target)) this.close() }
    document.addEventListener("click", this.onDocumentClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
    clearTimeout(this.statusTimer)
  }

  get isOpen() { return !this.menuTarget.hidden }

  toggle() { this.isOpen ? this.close() : this.open(0) }

  open(index) {
    this.menuTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.focusItem(index)
  }

  close({ focusButton = false } = {}) {
    if (!this.isOpen) return
    this.menuTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
    if (focusButton) this.buttonTarget.focus()
  }

  focusItem(index) {
    const items = this.itemTargets
    items[(index + items.length) % items.length]?.focus()
  }

  keydown(event) {
    const onButton = event.target === this.buttonTarget
    if (onButton && (event.key === "ArrowDown" || event.key === "ArrowUp")) {
      event.preventDefault()
      this.open(event.key === "ArrowDown" ? 0 : -1)
      return
    }
    if (!this.isOpen) return
    const index = this.itemTargets.indexOf(event.target)
    switch (event.key) {
      case "Escape": event.preventDefault(); this.close({ focusButton: true }); break
      case "Tab": this.close(); break
      case "ArrowDown": event.preventDefault(); this.focusItem(index + 1); break
      case "ArrowUp": event.preventDefault(); this.focusItem(index - 1); break
      case "Home": event.preventDefault(); this.focusItem(0); break
      case "End": event.preventDefault(); this.focusItem(-1); break
    }
  }

  openDialog(event) {
    const dialog = document.getElementById(event.currentTarget.dataset.dialogId)
    this.close()
    if (!dialog) return
    dialog.addEventListener("close", () => this.buttonTarget.focus(), { once: true })
    dialog.showModal()
  }

  async copyLink(event) {
    const url = event.currentTarget.dataset.url
    try { await navigator.clipboard.writeText(url) } catch (_) { /* no clipboard: the address is in the browser's bar */ }
    this.close({ focusButton: true })
    this.statusTarget.textContent = this.copiedValue
    clearTimeout(this.statusTimer)
    this.statusTimer = setTimeout(() => { this.statusTarget.textContent = "" }, 3000)
  }
}
