# frozen_string_literal: true

module NexusCcs
  # The home page's "All University collections": every collection of the University, so a visitor can see what is here and what is not
  # yet. Those with records are searched in place; the others link to the collection's own site (UniversityCollections).
  class CollectionDirectoryComponent < ViewComponent::Base
    def here = UniversityCollections.in_collections_navigator

    def elsewhere = UniversityCollections.elsewhere

    def count = UniversityCollections.all.size
  end
end
