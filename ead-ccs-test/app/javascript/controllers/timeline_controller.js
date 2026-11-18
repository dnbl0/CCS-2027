import { Controller } from "@hotwired/stimulus"

// Explore by time (app/views/explore/time.html.erb): the periods are a list of links, all in the Tab order. On a period, Left and
// Right move to the one before or after it, Home and End to the first and last, scrolling the strip without animation when the
// visitor asks for reduced motion. Without JavaScript the list works as it is.
export default class extends Controller {
  static targets = ["link"]

  // The strip opens on the period with the most records (most are 19th and 20th century), centred, by scrolling the strip
  // itself: the page does not move and nothing animates
  connect() {
    if (this.element.scrollWidth <= this.element.clientWidth) return

    const busiest = this.linkTargets.reduce((best, link) => (Number(link.dataset.count) > Number(best?.dataset.count ?? -1) ? link : best), null)
    const period = busiest?.closest("li")
    if (!period) return

    this.element.scrollLeft = period.offsetLeft - (this.element.clientWidth - period.offsetWidth) / 2
  }

  move(event) {
    const keys = { ArrowLeft: -1, ArrowRight: 1, Home: "first", End: "last" }
    if (!(event.key in keys) || event.altKey || event.ctrlKey || event.metaKey) return

    const links = this.linkTargets
    const index = links.indexOf(event.currentTarget)
    const step = keys[event.key]
    const next = step === "first" ? 0 : step === "last" ? links.length - 1 : index + step
    if (next < 0 || next >= links.length || next === index) return

    event.preventDefault()
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    links[next].focus({ preventScroll: true })
    links[next].scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "nearest", inline: "nearest" })
  }
}
