# frozen_string_literal: true

module NexusCcs
  # The site's card in its collage variant (Record types on the home page; after Google Arts & Culture's multi-picture cards): a few of
  # the kind's own records side by side at one height, each picture whole at its own shape (so the card is as wide as its pictures),
  # then the name and the number of records. The pictures are decorative (the name is the link text). collage: HomeSections::Collage.
  class CollageCardComponent < ViewComponent::Base
    def initialize(collage:)
      @collage = collage
    end

    attr_reader :collage
  end
end
