// OpenSeadragon, set up the one way the record page's zoom (deep_zoom_controller) and the comparison panes (compare_controller)
// share (CCS-57, CCS-58). Not a Stimulus controller: it is imported on demand, so OpenSeadragon (the largest script on the site)
// is fetched only when a visitor starts to zoom or opens the comparison page, never by an ordinary page view.
//
// A source is { url, info, alt }: info is an IIIF Image API info.json URL when the record has one (tiles are then asked of the
// image server), otherwise the plain image file. The mouse wheel does not zoom: it would take the page's scroll away from
// someone who is only scrolling past (WCAG 2.1.1, 2.4.3). Buttons, the keyboard (arrows pan, = and - zoom, 0 resets), a
// double click and a pinch do.

export const KEYBOARD_HINT = "Arrow keys pan. The equals and minus keys zoom in and out, and 0 resets the view."

export function tileSource(source) {
  return source.info ? source.info : { type: "image", url: source.url }
}

// A plain image on another host (a DAM embed link, 2000px) is drawn as it is, without asking for CORS headers the host may not send.
// OpenSeadragon's WebGL drawer cannot use such an image (it would warn, then fall back), so the canvas drawer is used from the start.
export function crossOriginImage(source) {
  if (source.info) return false
  try { return new URL(source.url, window.location.href).origin !== window.location.origin } catch { return false }
}

export function prefersReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches
}

// element: an empty block with a height. Returns the viewer, whose canvas (the focusable part) is named for screen readers.
export async function createViewer(element, source, { label } = {}) {
  const { default: OpenSeadragon } = await import("openseadragon")
  const viewer = OpenSeadragon({
    element,
    tileSources: tileSource(source),
    showNavigationControl: false,
    showNavigator: false,
    showRotationControl: false,
    gestureSettingsMouse: { scrollToZoom: false, clickToZoom: false, dblClickToZoom: true },
    animationTime: prefersReducedMotion() ? 0 : 0.8,
    visibilityRatio: 1,
    constrainDuringPan: true,
    maxZoomPixelRatio: 3,
    crossOriginPolicy: source.info ? "Anonymous" : false,
    drawer: crossOriginImage(source) ? "canvas" : ["webgl", "canvas", "html"],
    tabIndex: 0
  })
  nameCanvas(viewer, label || source.alt)
  return viewer
}

// The image is drawn on a canvas, which has no text of its own: the focusable area carries the name and how to use the keys.
export function nameCanvas(viewer, label) {
  const canvas = viewer.canvas
  canvas.setAttribute("role", "group")
  canvas.setAttribute("aria-label", `${label}. ${KEYBOARD_HINT}`)
}

export function open(viewer, source, label) {
  viewer.open(tileSource(source))
  nameCanvas(viewer, label || source.alt)
}

// Each step is from the zoom being moved to (the target), not the one on screen mid-animation, so quick presses add up evenly
export function zoomIn(viewer) { viewer.viewport.zoomTo(viewer.viewport.getZoom(true) * 1.5); viewer.viewport.applyConstraints() }
export function zoomOut(viewer) { viewer.viewport.zoomTo(viewer.viewport.getZoom(true) / 1.5); viewer.viewport.applyConstraints() }
export function reset(viewer) { viewer.viewport.goHome() }

// Whether the view shows the whole picture (or less): zooming out from here closes the record page's viewer
export function atHome(viewer) { return viewer.viewport.getZoom(true) <= viewer.viewport.getHomeZoom() * 1.01 }

// Resolves once the first image has opened and the viewer has settled on the whole picture (it fits the image to the box just after
// the open event), so a zoom made straight after opening is not undone by that fit
export function opened(viewer) {
  const settle = () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => { viewer.viewport.goHome(true); resolve() })))
  if (viewer.world.getItemCount() > 0) return settle()
  return new Promise((resolve) => {
    viewer.addOnceHandler("open", () => settle().then(resolve))
    viewer.addOnceHandler("open-failed", () => resolve())
  })
}
