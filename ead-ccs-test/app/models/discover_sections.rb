# frozen_string_literal: true

# The sections of the home page's "Featured and trending" and of /discover, with the records in each (docs/similar-and-trending.md):
#
#   pick      Pick of the day: one record, the same all day (FeaturedRecords.pick_of_the_day)
#   featured  the curated picks (config/featured.yml)
#   trending  the most viewed records of the last few days (RecordView); absent while the data is thin or TRENDING_ENABLED is off
#
# A section with no records is left out. Every record is one the sections may list (Discovery.listable?), so a record whose
# asset is withheld or sensitive is in none of them. Each Solr or database failure leaves its own section out and nothing else.
class DiscoverSections
  Section = Data.define(:key, :entries)

  # limit: how many records the featured and trending sections show
  def self.build(limit:)
    pick = FeaturedRecords.pick_of_the_day
    sections = [
      Section.new(:pick, pick ? [ FeaturedRecords::Entry.new(document: pick, blurb: nil) ] : []),
      Section.new(:featured, FeaturedRecords.picks(limit: limit)),
      Section.new(:trending, TrendingRecords.documents(limit: limit).map { |document| FeaturedRecords::Entry.new(document: document, blurb: nil) })
    ]
    sections.reject { |section| section.entries.empty? }
  end
end
