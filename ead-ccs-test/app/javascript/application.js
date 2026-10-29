// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "page_loader" // first, so the loading screen always comes off even if a later import fails
import "@hotwired/turbo-rails"
import "controllers"
import "search_loading"
import "modal_lock"
import "smooth_scroll"
import * as bootstrap from "bootstrap"
import githubAutoCompleteElement from "@github/auto-complete-element"
import Blacklight from "blacklight-frontend"
import "blacklight-gallery"

import BlacklightRangeLimit from "blacklight-range-limit";
BlacklightRangeLimit.init({onLoadHandler: Blacklight.onLoad });
