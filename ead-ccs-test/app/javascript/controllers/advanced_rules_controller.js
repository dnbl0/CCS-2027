import { Controller } from "@hotwired/stimulus"

// The rules of the Advanced search form: adds and removes the extra rules in place. Without JavaScript the same buttons send the
// form to the Advanced search page, which draws it again with one more (add_rule) or one fewer (remove_rule) row.
//   - after a rule is added, focus goes to its Field menu; after one is removed, to the next rule's Field menu, else the one
//     before, else the "Add another rule" button;
//   - each change is said politely in a status (the region is in the page already, so it is announced);
//   - at the most (max), the button says so with aria-disabled and is not removed from the tab order, so focus is never lost.
// The text of a "has a value" / "is empty" rule is not needed, so its box is switched off; a field's menu offers only the matches
// that field has (data-matches on its options).
export default class extends Controller {
  static targets = ["list", "template", "status", "add", "row", "legend", "removeName"]
  static values = { max: Number, nextKey: Number, added: String, addedLast: String, removedOne: String, removedOther: String, limit: String }

  connect() {
    this.element.querySelectorAll("[data-advanced-rules-target='row']").forEach((row) => this.syncMatches(row))
    this.syncAddButton()
    this.element.dataset.ready = "true" // the buttons now work in place (until then they send the form, which also works)
  }

  add(event) {
    event.preventDefault()
    if (this.rowTargets.length >= this.maxValue) {
      this.say(this.limitValue)
      return
    }

    const key = this.nextKeyValue++
    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML.replaceAll("__KEY__", key))
    this.renumber()
    const row = this.rowTargets[this.rowTargets.length - 1]
    this.syncMatches(row)
    row.querySelector("select")?.focus()
    const number = this.rowTargets.length
    const left = this.maxValue - number
    this.say(left > 0 ? this.addedValue.replace("%{number}", number).replace("%{left}", left) : this.addedLastValue.replace("%{number}", number))
    this.syncAddButton()
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-advanced-rules-target='row']")
    const rows = this.rowTargets
    const index = rows.indexOf(row)
    const neighbour = rows[index + 1] || rows[index - 1]
    row.remove()
    this.renumber()
    if (neighbour) neighbour.querySelector("select")?.focus()
    else this.addTarget.focus()

    const count = this.rowTargets.length
    this.say(count === 1 ? this.removedOneValue : this.removedOtherValue.replace("%{count}", count))
    this.syncAddButton()
  }

  fieldChanged(event) {
    this.syncMatches(event.currentTarget.closest("[data-advanced-rules-target='row']"))
  }

  matchChanged(event) {
    const select = event.currentTarget
    const term = select.closest(".advanced-rule").querySelector("[data-advanced-rules-target='term']")
    if (term) term.disabled = ["present", "empty"].includes(select.value)
  }

  // "Additional rule 2" after one before it is removed
  renumber() {
    this.legendTargets.forEach((legend, index) => {
      const text = legend.dataset.template.replace("%{number}", index + 1)
      legend.textContent = text
    })
    this.removeNameTargets.forEach((name, index) => { name.textContent = ` ${this.legendTargets[index].textContent.toLowerCase()}` })
  }

  // Only the matches the chosen field has; a match it does not have is not chosen
  syncMatches(row) {
    const field = row.querySelector("[data-advanced-rules-target='field']")
    const match = row.querySelector("[data-advanced-rules-target='match']")
    if (!field || !match) return

    const allowed = (field.selectedOptions[0]?.dataset.matches || "").split(" ")
    Array.from(match.options).forEach((option) => { option.disabled = !allowed.includes(option.value) })
    if (match.selectedOptions[0]?.disabled) match.value = "contains"
    match.dispatchEvent(new Event("change"))
  }

  syncAddButton() {
    this.addTarget.setAttribute("aria-disabled", this.rowTargets.length >= this.maxValue ? "true" : "false")
    if (this.rowTargets.length < this.maxValue) this.addTarget.removeAttribute("aria-disabled")
  }

  say(text) {
    this.statusTarget.textContent = ""
    // Cleared first so the same sentence said twice is announced twice
    window.requestAnimationFrame(() => { this.statusTarget.textContent = text })
  }
}
