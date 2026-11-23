import { Controller } from "@hotwired/stimulus"

// An eBook (EPUB) on the record page (CCS-164, media_viewers/_ebook): epub.js shows it a page at a time, imported only when a record
// has one. Previous and Next page (or the arrow keys, on the buttons or in the book) turn the page; Contents goes to a chapter; the
// status says where the reader is. The book's own scripts never run (allowScriptedContent: false).
export default class extends Controller {
  static targets = [ "stage", "status", "previous", "next", "contents", "chapter" ]
  static values = { src: String, title: String }

  async connect() {
    this.say("Loading the eBook…")
    try {
      const { default: ePub } = await import("epub_reader")
      if (!this.element.isConnected) return

      this.book = ePub(this.srcValue, { openAs: "epub" })
      this.rendition = this.book.renderTo(this.stageTarget, { width: "100%", height: "100%", flow: "paginated", spread: "none",
                                                              allowScriptedContent: false })
      // the book's own styles win; a book with none reads at a comfortable line height rather than the browser's tight default
      this.rendition.themes.default({ body: { "line-height": "1.6" } })
      this.rendition.on("rendered", (_section, view) => view.iframe?.setAttribute("title", this.titleValue))
      this.rendition.on("relocated", (location) => this.relocated(location))
      this.rendition.on("keyup", (event) => this.key(event))
      await this.rendition.display()
      await this.book.loaded.navigation.then((navigation) => this.listContents(navigation.toc)).catch(() => {})
      this.element.classList.add("is-ready")
    } catch (_) {
      this.failed()
    }
  }

  disconnect() {
    this.book?.destroy()
    this.book = this.rendition = null
  }

  previous() { if (this.previousTarget.getAttribute("aria-disabled") !== "true") this.rendition?.prev() }
  next() { if (this.nextTarget.getAttribute("aria-disabled") !== "true") this.rendition?.next() }

  key(event) {
    if (event.key === "ArrowLeft") this.previous()
    else if (event.key === "ArrowRight") this.next()
  }

  choose(event) { if (event.target.value) this.rendition?.display(event.target.value) }

  // Where the reader is: the page within the chapter, and the first and last pages greyed out (aria-disabled keeps the button focusable)
  relocated(location) {
    const { page, total } = location.start.displayed
    this.say(total > 1 ? `Page ${page} of ${total} in this chapter` : "")
    this.previousTarget.setAttribute("aria-disabled", location.atStart ? "true" : "false")
    this.nextTarget.setAttribute("aria-disabled", location.atEnd ? "true" : "false")
    const href = location.start.href
    if (this.hasContentsTarget && href) {
      const option = [ ...this.contentsTarget.options ].find((item) => item.value.split("#")[0] === href)
      if (option) this.contentsTarget.value = option.value
    }
  }

  listContents(toc) {
    if (!this.hasContentsTarget || !toc?.length) return
    const add = (items, depth) => items.forEach((item) => {
      this.contentsTarget.add(new Option(`${" ".repeat(depth)}${item.label.trim()}`, item.href))
      if (item.subitems?.length) add(item.subitems, depth + 1)
    })
    add(toc, 0)
    this.chapterTarget.hidden = false
  }

  failed() {
    this.element.classList.add("is-failed")
    this.say("This eBook could not be shown here.")
  }

  say(text) { if (this.hasStatusTarget) this.statusTarget.textContent = text }
}
