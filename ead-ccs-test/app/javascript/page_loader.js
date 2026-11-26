// Takes the page loading screen away (components/page_loader.css) once the page, its images and its scripts have
// loaded. Turbo visits keep the same <html>, so it only ever shows for the first load of the site.
const ready = () => document.documentElement.classList.add("page-ready")

if (document.readyState === "complete") {
  ready()
} else {
  window.addEventListener("load", ready, { once: true })
}

// Pictures come in gracefully (components/image_reveal.css; after Google Arts & Culture, whose pictures appear on a flat colour, then
// fade in once whole): a picture is marked is-revealed once it has loaded, or failed, so the stylesheet can fade it in over its frame's
// colour instead of it drawing in strips at its own pace. Load events do not bubble, so one listener on the document in the capture phase
// hears every picture's, including those added later (a Turbo frame's wall, a lazy picture scrolled to); pictures already complete when
// this runs, or brought back from Turbo's cache, are marked straight away.
const reveal = (img) => img.classList.add("is-revealed")
const revealComplete = () => document.querySelectorAll("img:not(.is-revealed)").forEach((img) => {
  if (!img.complete) return
  if (img.naturalWidth === 0 && img.getAttribute("src")) img.classList.add("is-failed") // failed before this script ran
  reveal(img)
})
// A picture that fails (a University site refusing it, a moved file) is marked is-failed too, so the stylesheet can show a tidy frame
// in its place instead of the browser's broken-picture box (docs/ux-drift-audit.md A8)
const onPicture = (event) => {
  if (!(event.target instanceof HTMLImageElement)) return
  if (event.type === "error") event.target.classList.add("is-failed")
  reveal(event.target)
}

document.addEventListener("load", onPicture, true)
document.addEventListener("error", onPicture, true)
revealComplete()
document.addEventListener("DOMContentLoaded", revealComplete)
document.addEventListener("turbo:render", revealComplete)
document.addEventListener("turbo:frame-render", revealComplete)
