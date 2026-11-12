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
// navigatorId: the id of an element to draw the navigator (a small map of the whole image, its visible part outlined) in; none, no
// navigator. describedBy: the id of a visually hidden description the canvas points at.
export async function createViewer(element, source, { label, navigatorId, describedBy } = {}) {
  const { default: OpenSeadragon } = await import("openseadragon")
  const viewer = OpenSeadragon({
    element,
    tileSources: tileSource(source),
    showNavigationControl: false,
    showNavigator: Boolean(navigatorId),
    navigatorId,
    showRotationControl: false,
    gestureSettingsMouse: { scrollToZoom: false, clickToZoom: false, dblClickToZoom: true },
    animationTime: prefersReducedMotion() ? 0 : 0.8,
    minZoomImageRatio: 1, // zoom out stops at the picture fitting its stage
    visibilityRatio: 0.5, // the whole picture shows at home whatever the stage's shape; it can be moved until half of it is in view
    constrainDuringPan: true,
    maxZoomPixelRatio: 3,
    crossOriginPolicy: source.info ? "Anonymous" : false,
    tabIndex: 0
  })
  nameCanvas(viewer, label || source.alt, describedBy)
  // The wheel is not used to zoom here, so it must not be swallowed either: leave it to the page, so scrolling over the picture scrolls the page
  viewer.addHandler("canvas-scroll", (event) => { event.preventDefaultAction = true; event.preventDefault = false })
  return viewer
}

// The image is drawn on a canvas, which has no text of its own: the focusable area carries the name and how to use the keys.
export function nameCanvas(viewer, label, describedBy) {
  const canvas = viewer.canvas
  canvas.setAttribute("role", describedBy ? "application" : "group")
  canvas.setAttribute("aria-label", `${label}. ${KEYBOARD_HINT}`)
  if (describedBy) canvas.setAttribute("aria-describedby", describedBy)
}

export function open(viewer, source, label, describedBy) {
  viewer.open(tileSource(source))
  nameCanvas(viewer, label || source.alt, describedBy)
}

// Whether the view can still go in or out, for the buttons to be disabled at the limits
export function limits(viewer) {
  const zoom = viewer.viewport.getZoom()
  return { canZoomIn: zoom < viewer.viewport.getMaxZoom() - 1e-6, canZoomOut: zoom > viewer.viewport.getMinZoom() * 1.001 }
}

export function zoomIn(viewer) { viewer.viewport.zoomBy(1.5); viewer.viewport.applyConstraints() }
export function zoomOut(viewer) { viewer.viewport.zoomBy(1 / 1.5); viewer.viewport.applyConstraints() }
export function reset(viewer) { viewer.viewport.goHome() }
