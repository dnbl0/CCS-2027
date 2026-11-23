import { Controller } from "@hotwired/stimulus"

// The record's description, collapsed with a Show more / Show less button (RecordDocumentComponent). Collapsed (CCS-413), the first paragraph
// (the lead) is clamped to two lines and the paragraphs after it are hidden (the hidden attribute, so a screen reader skips them
// too); expanded, all of it shows, its paragraphs kept. The button says whether the text is open (aria-expanded) and stays where it
// is; collapsing a long text brings its start back into view. Nothing to collapse (one short paragraph): no button. Without
// JavaScript the whole description shows.
export default class extends Controller {
  static targets = [ "text", "lead", "more", "toggle" ]
  static values = { moreLabel: { type: String, default: "Show more" }, lessLabel: { type: String, default: "Show less" } }

  connect() {
    this.expanded = false
    this.render()
    if (!this.hasMoreTarget && !this.leadOverflows()) {
      this.expanded = true // nothing is cut: show it all, with no button
      this.render()
      return
    }
    this.toggleTarget.hidden = false
  }

  toggle() {
    this.expanded = !this.expanded
    this.render()
    if (!this.expanded && this.textTarget.getBoundingClientRect().top < 0) {
      this.textTarget.scrollIntoView({ block: "start", behavior: "instant" })
    }
  }

  render() {
    this.textTarget.classList.toggle("is-collapsed", !this.expanded)
    this.moreTargets.forEach((paragraph) => { paragraph.hidden = !this.expanded })
    this.toggleTarget.textContent = this.expanded ? this.lessLabelValue : this.moreLabelValue
    this.toggleTarget.setAttribute("aria-expanded", String(this.expanded))
  }

  leadOverflows() {
    const lead = this.hasLeadTarget ? this.leadTarget : null
    return lead !== null && lead.scrollHeight > lead.clientHeight + 1
  }
}
