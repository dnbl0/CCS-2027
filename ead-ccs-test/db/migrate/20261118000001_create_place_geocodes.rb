# Where the records' production places are (docs/time-and-place.md): one row per distinct production_place_ssim value, looked
# up once with OpenStreetMap Nominatim by `rake geo:geocode` and kept, including "not found", so a run resumes and never asks twice.
# `rake geo:write` writes the coordinates and the place hierarchy into the DAM index (DAM_SOLR_URL) from here.
class CreatePlaceGeocodes < ActiveRecord::Migration[8.1]
  def change
    create_table :place_geocodes do |t|
      t.string :place, null: false          # the value exactly as in the index
      t.string :normalised, null: false     # brackets, "(?)" and spacing taken out, lower case: two spellings share one lookup
      t.float :lat
      t.float :lon
      t.string :country
      t.string :country_code
      t.string :state
      t.string :locality
      t.string :region                       # the commonest region_ssim of the place's records, else the continent of the country
      t.string :kind                         # region, country, state or place: how far down the hierarchy the place goes
      t.string :source                       # "nominatim", or "manual" for a row corrected by hand
      t.datetime :looked_up_at
      t.boolean :not_found, null: false, default: false
      t.timestamps
    end
    add_index :place_geocodes, :place, unique: true
    add_index :place_geocodes, :normalised
  end
end
