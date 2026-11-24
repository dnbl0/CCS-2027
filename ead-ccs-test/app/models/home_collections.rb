# frozen_string_literal: true

# The home page's collections as the University's Museums and Collections index lists them (config/home_collections.yml): its 24
# collections, and the 12 collections within the University of Melbourne Art Collection, with the same titles and pictures. Each item
# opens its page here (Item#path).
module HomeCollections
  FILE = Rails.root.join("config/home_collections.yml")
  Item = Data.define(:title, :image, :named, :maker, :url)

  module_function

  def museums = list("museums")

  def art_collection = list("art_collection")

  def list(key)
    @lists ||= YAML.safe_load_file(FILE)
    Array(@lists[key]).map { |row| Item.new(title: row["title"].to_s.strip, image: row["image"], named: row["named"], maker: row["maker"], url: row["url"].presence) }
  end

  # A collection's own page here; a sub-collection's named collection, or its maker's page. Where this site has none (its records are not
  # here: 11 of the 24 collections), the collection's page on the University's sites (url), never a search that finds nothing
  # (docs/ia-audit-handover.md); with no url either, its records in the search
  def path(item, helpers)
    own = if item.named then helpers.landing_path_for("named-collections", item.named)
    elsif item.maker then Browse.path_for("makers", item.maker)
    else helpers.landing_path_for("collections", item.title)
    end
    own || item.url || helpers.search_action_path(search_query(item))
  end

  def search_query(item)
    return BrowseHubs.query("named_collection_ssim", item.named) if item.named
    return BrowseHubs.query("creator_ssim", item.maker) if item.maker

    BrowseHubs.query(ExploreEntryPoints::COLLECTION_FIELD, item.title)
  end

  # A path on another site (the University's): the listing says so to screen readers and opens it as an ordinary link
  def external?(path) = path.to_s.start_with?("http://", "https://")
end
