# frozen_string_literal: true

module NexusCcs
  # The home page's "All University collections": every collection of the University, so a visitor can see what is here and what is not
  # yet. Those with records are searched in place; the others link to the collection's own site (UniversityCollections).
  class CollectionDirectoryComponent < ViewComponent::Base
    # counts: { collection_ssim value => records } (the index's, unless a test passes its own)
    def initialize(counts: UniversityCollections.counts)
      @counts = counts
    end

    def here = UniversityCollections.in_collections_navigator(@counts)

    def elsewhere = UniversityCollections.elsewhere(@counts)

    def count = UniversityCollections.all(@counts).size

    def search_path(entry) = helpers.search_action_path(entry.search_params)
  end
end
