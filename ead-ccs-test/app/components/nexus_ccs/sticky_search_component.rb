# frozen_string_literal: true

module NexusCcs
  # A slim navy strip fixed to the top of the window: the site title on the left, the search bar in the centre and the
  # "Advanced search" link on the right. It slides in once the page's banner has scrolled out of view and slides away
  # again when the banner comes back (controllers/sticky_search_controller.js). Layout is Bootstrap's own
  # (position-fixed, container, d-grid) over Blacklight's search bar, so it sits with Blacklight's markup.
  class StickySearchComponent < ViewComponent::Base
    # The first of these on the page is "the banner": the home page hero, the search banner and the content pages' banner.
    BANNERS = ".ccs-hero, .search-banner, .page-banner"

    def initialize(blacklight_config:)
      @blacklight_config = blacklight_config
    end

    attr_reader :blacklight_config
  end
end
