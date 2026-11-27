# Pin npm packages by running ./bin/importmap
pin "application"
pin "search_loading"
pin "page_loader"
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
# OpenSeadragon (vendored ES module): not preloaded (CCS-71); deep_zoom_viewer.js imports it when a visitor opens the zoom
pin "openseadragon", to: "openseadragon.js", preload: false
# The openseadragon gem pins its own Rails glue for every page; this later pin of the same directory stops it being preloaded
pin_all_from File.join(Gem.loaded_specs.fetch("openseadragon").full_gem_path, "app/javascript/openseadragon-rails"),
  under: "openseadragon-rails", preload: false
# Leaflet 1.9.4 (vendored ES module, BSD-2-Clause): the Explore by place map only. Not preloaded: place_map_controller imports it
# when the visitor asks for the map, so no other page loads it.
pin "leaflet", to: "leaflet.js", preload: false
