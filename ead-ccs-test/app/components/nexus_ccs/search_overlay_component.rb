# frozen_string_literal: true

module NexusCcs
  # Full-screen search opened by the header's search button. Like the global search on unimelb.edu.au it searches the
  # University of Melbourne website (search.unimelb.edu.au), not this site's records: records are searched from the
  # sticky search strip and the "Search collections" menu.
  class SearchOverlayComponent < Blacklight::Component
    UNIMELB_SEARCH_URL = "https://search.unimelb.edu.au/s/search.html"
    UNIMELB_SEARCH_COLLECTION = "uom~sp-global"
  end
end
