# frozen_string_literal: true

# The home page's collections as the University's Museums and Collections index lists them (config/home_collections.yml): its 24
# collections, and the 12 collections within the University of Melbourne Art Collection, with the same titles and pictures. Each item
# opens its page here (Item#path).
module HomeCollections
  FILE = Rails.root.join("config/home_collections.yml")
  Item = Data.define(:title, :image, :named, :maker)

  module_function

  def museums = list("museums")

  def art_collection = list("art_collection")

  def list(key)
    @lists ||= YAML.safe_load_file(FILE)
    Array(@lists[key]).map { |row| Item.new(title: row["title"].to_s.strip, image: row["image"], named: row["named"], maker: row["maker"]) }
  end

  # A collection's own page (else its records in the search); a sub-collection's named collection, or its maker's page (else its records)
  def path(item, helpers)
    return helpers.landing_path_for("named-collections", item.named) || helpers.search_action_path(BrowseHubs.query("named_collection_ssim", item.named)) if item.named
    return Browse.path_for("makers", item.maker) || helpers.search_action_path(BrowseHubs.query("creator_ssim", item.maker)) if item.maker

    helpers.landing_path_for("collections", item.title) || helpers.search_action_path(BrowseHubs.query(ExploreEntryPoints::COLLECTION_FIELD, item.title))
  end
end
