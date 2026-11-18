# frozen_string_literal: true

# The records whose colours are closest to one record's, closest first (rake colour:neighbours): what "Looks similar" lists
class ColourNeighbour < ApplicationRecord
  def self.ids_for(record_id) = where(record_id: record_id.to_s).pick(:neighbour_ids) || []
end
