# frozen_string_literal: true

module Colour
  # rake colour:neighbours: for every record in record_colours, the records whose colours are closest, kept in colour_neighbours,
  # so "Looks similar" on a record page is one database lookup and one Solr request.
  #
  # The distance between two records is half the sum of the differences of their 64-box colour histograms (Colour::Palette#histogram):
  # 0 for the same colours in the same amounts, 1 for no colour in common. Up to KEEP records under MAX_DISTANCE are kept, closest
  # first (more than the page shows, so it can leave out records that are no longer viewable). Every pair is compared, so the time
  # grows with the square of the number of records: about 2,000 records take seconds; at 20,000 or more, compare within colour names.
  class Neighbours
    KEEP = 16
    MAX_DISTANCE = 0.6
    BOXES = 64

    # Returns how many records have neighbours
    def run
      ids, vectors = load
      now = Time.current
      rows = ids.each_with_index.filter_map do |id, index|
        closest = closest_to(index, vectors).map { |other| ids[other] }
        { record_id: id, neighbour_ids: closest, computed_at: now } if closest.any?
      end
      ColourNeighbour.transaction do
        ColourNeighbour.delete_all
        rows.each_slice(1_000) { |slice| ColourNeighbour.insert_all(slice) }
      end
      rows.size
    end

    # Half the L1 distance of two histograms (arrays of BOXES shares)
    def self.distance(one, other)
      sum = 0.0
      index = 0
      while index < BOXES
        sum += (one[index] - other[index]).abs
        index += 1
      end
      sum / 2
    end

    private

    def load
      rows = RecordColour.extracted.order(:record_id).pluck(:record_id, :histogram)
      [ rows.map(&:first), rows.map { |_id, histogram| Array.new(BOXES) { |box| histogram[box.to_s].to_f } } ]
    end

    def closest_to(index, vectors)
      mine = vectors[index]
      scored = []
      vectors.each_with_index do |other, position|
        next if position == index

        distance = self.class.distance(mine, other)
        scored << [ distance, position ] if distance <= MAX_DISTANCE
      end
      scored.sort.first(KEEP).map(&:last)
    end
  end
end
