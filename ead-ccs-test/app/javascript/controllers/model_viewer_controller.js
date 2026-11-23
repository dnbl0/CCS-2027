import { Controller } from "@hotwired/stimulus"

// A 3D model in glTF or GLB on the record page (CCS-164, media_viewers/_model): Google's model-viewer, imported only when a record has
// such a file. Drag (or the arrow keys, once the model has focus) turns it; pinch or the Zoom buttons bring it closer; Reset view puts
// it back. Its draco and KTX2 decoders, fetched only for a model compressed with them, come from this site (decodersValue), not
// Google's CDN: model-viewer reads them from window.ModelViewerElement when it is first loaded.
export default class extends Controller {
  static targets = [ "stage", "status" ]
  static values = { src: String, alt: String, decoders: String }

  async connect() {
    this.say("Loading the 3D model…")
    self.ModelViewerElement ||= {}
    self.ModelViewerElement.dracoDecoderLocation ||= `${this.decodersValue}/draco/`
    self.ModelViewerElement.ktx2TranscoderLocation ||= `${this.decodersValue}/basis/`
    try {
      await import("@google/model-viewer")
    } catch (_) {
      return this.failed()
    }
    if (!this.element.isConnected) return

    const viewer = document.createElement("model-viewer")
    viewer.className = "model-viewer__model"
    viewer.setAttribute("src", this.srcValue)
    viewer.setAttribute("alt", this.altValue)
    viewer.setAttribute("camera-controls", "")
    viewer.setAttribute("touch-action", "pan-y") // a vertical swipe still scrolls the page on a phone
    viewer.setAttribute("interaction-prompt", "none") // the hint under the model says how, with no moving hand
    viewer.setAttribute("shadow-intensity", "1")
    viewer.addEventListener("load", () => { this.element.classList.add("is-ready"); this.say("") })
    viewer.addEventListener("error", () => this.failed())
    this.stageTarget.append(viewer)
    this.viewer = viewer
  }

  disconnect() {
    this.viewer?.remove()
    this.viewer = null
  }

  zoomIn() { this.viewer?.zoom(1) }
  zoomOut() { this.viewer?.zoom(-1) }

  reset() {
    if (!this.viewer) return
    this.viewer.cameraOrbit = "auto auto auto"
    this.viewer.cameraTarget = "auto auto auto"
    this.viewer.fieldOfView = "auto"
    this.viewer.resetTurntableRotation(0)
    this.viewer.jumpCameraToGoal()
  }

  failed() {
    this.element.classList.remove("is-ready")
    this.element.classList.add("is-failed")
    this.viewer?.remove()
    this.viewer = null
    this.say("This 3D model could not be shown here.")
  }

  say(text) { if (this.hasStatusTarget) this.statusTarget.textContent = text }
}
