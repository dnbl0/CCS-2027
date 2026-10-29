// Turns on smooth scrolling for jumps within a page (pages/help.css: html.smooth-scroll) once the first load has settled.
// A page opened at an address with a #section must land there at once: with smooth scrolling on from the start the browser
// animates that first jump, and a slow load or a background tab can cut it short and leave the page at the top. Turbo visits
// keep the same <html>, so this runs once.
const enable = () => requestAnimationFrame(() => requestAnimationFrame(() => document.documentElement.classList.add("smooth-scroll")))

if (document.readyState === "complete") {
  enable()
} else {
  window.addEventListener("load", enable, { once: true })
}
