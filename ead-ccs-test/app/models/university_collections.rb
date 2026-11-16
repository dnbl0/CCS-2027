# frozen_string_literal: true

# Every University cultural collection (config/university_collections.yml: the list on museumsandcollections.unimelb.edu.au/collections),
# split into the ones whose records are in Collections Navigator (their name is a collection_ssim value in config/pages.yml) and the
# ones that are not yet, which link to their own site. The home page's "All University collections" lists both
# (NexusCcs::CollectionDirectoryComponent). Which collections have records is decided by the data, not by this list.
module UniversityCollections
  Entry = Data.define(:name, :url, :slug)

  def self.all
    @all ||= YAML.load_file(Rails.root.join("config/university_collections.yml")).map do |row|
      Entry.new(name: row.fetch("name"), url: row.fetch("url"), slug: slug_for(row.fetch("name")))
    end.freeze
  end

  def self.in_collections_navigator = all.select(&:slug)

  def self.elsewhere = all.reject(&:slug)

  def self.slug_for(name) = NexusCcs::SiteNavigation.slug_for(name)
  private_class_method :slug_for
end
