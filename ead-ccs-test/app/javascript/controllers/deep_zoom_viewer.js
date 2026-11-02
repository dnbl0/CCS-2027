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

export function zoomIn(viewer) { viewer.viewport.zoomBy(1.5); viewer.viewport.applyConstraints() }
export function zoomOut(viewer) { viewer.viewport.zoomBy(1 / 1.5); viewer.viewport.applyConstraints() }
export function reset(viewer) { viewer.viewport.goHome() }
