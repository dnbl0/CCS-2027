import { Controller } from "@hotwired/stimulus"

// Choosing results (CCS-40). The form above the results (SelectionBarComponent) works without JavaScript: tick, then Update
// selection. With it, each tick is saved as it is made, so the button is hidden, and the polite status line says the new
// count. The checkboxes sit in the cards, outside this form, and belong to it through their `form` attribute. The server
// (SelectionsController) keeps the selection in the session and answers with the ids it holds, which are what the page then
// shows: if the selection is full, the tick that did not fit is taken off again and the status says why.
export default class extends Controller {
  static targets = ["status", "update", "view"]
  static values = { max: Number, labels: Object, count: Number }

  connect() {
    if (this.hasUpdateTarget) this.updateTarget.hidden = true
    this.queue = Promise.resolve()
  }

  disconnect() {
    if (this.hasUpdateTarget) this.updateTarget.hidden = false
  }

  get boxes() {
    return Array.from(document.querySelectorAll(`input[type=checkbox][name="ids[]"][form="${this.element.id}"]`))
  }

  // A tick on one of this page's boxes (the action listens on the document, as the boxes are outside the form)
  changed(event) {
    const box = event.target
    if (!(box instanceof HTMLInputElement) || !this.boxes.includes(box)) return
    this.save("update", [box])
  }

  all(event) {
    event.preventDefault()
    this.boxes.forEach((box) => { box.checked = true })
    this.save("all", this.boxes)
  }

  clear(event) {
    event.preventDefault()
    this.boxes.forEach((box) => { box.checked = false })
    this.save("clear", this.boxes)
  }

  // One request at a time, in the order of the ticks, so the order selected is the order the visitor chose
  save(intent, boxes) {
    this.queue = this.queue.then(() => this.send(intent, boxes)).catch(() => this.failed(boxes))
  }

  async send(intent, boxes) {
    const body = new FormData()
    const token = this.element.querySelector("input[name=authenticity_token]")
    if (token) body.append("authenticity_token", token.value)
    body.append("intent", intent)
    body.append("return_to", location.pathname + location.search)
    boxes.forEach((box) => {
      body.append("page_ids[]", box.value)
      if (box.checked) body.append("ids[]", box.value)
    })
    const response = await fetch(this.element.action, { method: "POST", body, headers: { Accept: "application/json" }, credentials: "same-origin" })
    if (!response.ok) throw new Error(response.status)
    this.show(await response.json())
  }

  show(result) {
    const chosen = new Set(result.ids)
    this.boxes.forEach((box) => { box.checked = chosen.has(box.value) })
    this.countValue = result.count
    this.say(result.refused.length > 0 ? this.labelsValue.full : this.countText(result.count))
    if (this.hasViewTarget) this.viewTarget.textContent = this.labelsValue.view.replace("%{count}", result.count)
  }

  failed(boxes) {
    boxes.forEach((box) => { box.checked = !box.checked })
    this.say(this.labelsValue.error)
  }

  countText(count) {
    const labels = this.labelsValue
    if (count === 0) return labels.zero
    return (count === 1 ? labels.one : labels.other).replace("%{count}", count)
  }

  say(text) {
    this.statusTarget.textContent = text
  }
}
