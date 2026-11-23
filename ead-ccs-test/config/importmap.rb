# Pin npm packages by running ./bin/importmap
pin "application"
pin "search_loading"
pin "page_loader"
# The record viewer (OpenSeadragon) is for the two stock record pages only (CCS-71): other pages neither preload nor run it.
# preload: <entry point> preloads the module only on pages that load that entry point.
STOCK_ENTRIES = %w[stock_application branded_stock_application].freeze
pin "stock_application", preload: "stock_application"
pin "branded_stock_application", preload: "branded_stock_application"
pin "stock_media_viewer", preload: STOCK_ENTRIES
pin "modal_lock"
pin "smooth_scroll"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# Vendored ES modules (vendor/javascript); Bootstrap matches the bootstrap gem version
pin "bootstrap", to: "bootstrap.js"
pin "@popperjs/core", to: "popper-core.js"
pin "@github/auto-complete-element", to: "auto-complete-element.js"
pin "@github/combobox-nav", to: "combobox-nav.js"
# chart.js (and its one dependency) are a dependency of blacklight-range-limit. Vendored from the
# jsDelivr ES builds so the site makes no CDN requests; update versions together.
pin "chart.js", to: "chart.js"
pin "@kurkle/color", to: "kurkle-color.js"
# OpenSeadragon (vendored ES module); its Rails glue ("openseadragon-rails") is pinned by the openseadragon gem
pin "openseadragon", to: "openseadragon.js", preload: STOCK_ENTRIES
# The openseadragon gem pins its own files for every page; this later pin of the same directory narrows them
pin_all_from File.join(Gem.loaded_specs.fetch("openseadragon").full_gem_path, "app/javascript/openseadragon-rails"),
  under: "openseadragon-rails", preload: STOCK_ENTRIES
# Leaflet 1.9.4 (vendored ES module, BSD-2-Clause): the Explore by place map only. Not preloaded: place_map_controller imports it
# when the visitor asks for the map, so no other page loads it.
pin "leaflet", to: "leaflet.js", preload: false
# CCS-164, vendored from npm (versions in the repository's package.json), none preloaded: each is imported by its viewer's controller
# only on a record with such a file. Google model-viewer 4.4.0 (Apache-2.0; three.js inside, MIT): 3D models in glTF or GLB.
# Its draco and KTX2 decoders are served from public/vendor/model-viewer, not Google's CDN (model_viewer_controller.js).
pin "@google/model-viewer", to: "model-viewer.js", preload: false
# epub.js 0.3.93 (BSD-2-Clause) and the JSZip 3.10 it reads EPUB files with (MIT): eBooks. Both are UMD builds that set
# window.ePub and window.JSZip; epub_reader.js imports them in that order.
pin "jszip", to: "jszip.js", preload: false
pin "epubjs", to: "epub.js", preload: false
# The module that loads those two for ebook_reader_controller, imported only when a record has an eBook (outside controllers/, whose
# every file is preloaded)
pin "epub_reader", preload: false
