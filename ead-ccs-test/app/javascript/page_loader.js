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
const revealComplete = () => document.querySelectorAll("img:not(.is-revealed)").forEach((img) => { if (img.complete) reveal(img) })
const onPicture = (event) => { if (event.target instanceof HTMLImageElement) reveal(event.target) }

document.addEventListener("load", onPicture, true)
document.addEventListener("error", onPicture, true)
revealComplete()
document.addEventListener("DOMContentLoaded", revealComplete)
document.addEventListener("turbo:render", revealComplete)
document.addEventListener("turbo:frame-render", revealComplete)
