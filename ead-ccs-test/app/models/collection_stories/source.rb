# frozen_string_literal: true

class CollectionStories
  # A collection website whose stories are harvested (config/collection_story_sources.yml):
  #   name          the site's name, shown on each card ("Grainger Museum")
  #   collection    the collection_ssim value its records carry; a story matches only records of this collection
  #   index_url     the page that lists the stories
  #   story_prefix  the address every story starts with; other links on the list page are not stories
  #   hold          story address => why a reviewer keeps it off the record pages (it goes to the curator list)
  Source = Data.define(:name, :collection, :index_url, :story_prefix, :hold) do
    def self.load(path = SOURCES_PATH)
      Array(YAML.safe_load_file(path)).map do |entry|
        new(name: entry.fetch("name"), collection: entry.fetch("collection"), index_url: entry.fetch("index_url"),
            story_prefix: entry.fetch("story_prefix"), hold: entry.fetch("hold", nil) || {})
      end
    end

    def held?(url) = hold.key?(url)
  end
end
