// CCS-164: epub.js and the JSZip it opens EPUB files with, for ebook_reader_controller. Both are UMD builds that set a global
// (window.JSZip, window.ePub); a module's imports run in order, so JSZip is there when epub.js looks for it.
import "jszip"
import "epubjs"

export default window.ePub
