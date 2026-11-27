# frozen_string_literal: true

require "yaml"

# "Stories from the collection" on a record page: short articles a University collection's own website has published about an
# object (the Grainger Museum's "From the collection" first). The stories are harvested offline (bin/rails stories:harvest,
# CollectionStories::Harvester) into a reviewed data file, config/collection_stories.yml; the record page reads only that file and
# never fetches another site. Museums Victoria's stories about University objects (scripts/museums-victoria/) have their own file,
# config/collection_stories_museums_victoria.yml, so a Grainger harvest never overwrites them; both are read together. A story belongs on a record only when the record's accession number AND collection both match the
# story's, exactly. The file's "unmatched" list is for a curator and is never shown. docs/collection-stories.md explains it.
class CollectionStories
  PATH = Rails.root.join("config/collection_stories.yml")
  MUSEUMS_VICTORIA_PATH = Rails.root.join("config/collection_stories_museums_victoria.yml")
  SOURCES_PATH = Rails.root.join("config/collection_story_sources.yml")

  class FetchError < StandardError; end

  Story = Data.define(:title, :url, :image_url, :summary, :site, :collection, :accession_numbers) do
    def self.from(entry)
      url = https(entry["url"])
      return unless url && entry["title"].present? && entry["collection"].present?

      new(title: entry["title"].to_s, url: url, image_url: https(entry["image_url"]), summary: entry["summary"].to_s,
          site: entry["site"].to_s, collection: entry["collection"].to_s, accession_numbers: Array(entry["accession_numbers"]).map(&:to_s))
    end

    # Only an https address with a host is linked or loaded (the file is reviewed, but a slip must not become a script link)
    def self.https(value)
      uri = URI.parse(value.to_s)
      uri.to_s if uri.is_a?(URI::HTTPS) && uri.host.present?
    rescue URI::Error
      nil
    end
  end

  def self.default = @default ||= load(PATH, MUSEUMS_VICTORIA_PATH)

  # The stories of every file, in order. An unreadable, missing or malformed file is logged and adds no stories: it never breaks a
  # record page
  def self.load(*paths)
    new("stories" => paths.flat_map { |path| Array(read(path)["stories"]) })
  end

  def self.read(path)
    data = YAML.safe_load_file(path)
    data.is_a?(Hash) ? data : {}
  rescue StandardError => e
    Rails.logger.warn("CollectionStories: #{path} not read (#{e.class}: #{e.message})")
    {}
  end
  private_class_method :read

  def initialize(data)
    @index = Hash.new { |hash, key| hash[key] = [] }
    Array(data["stories"]).each do |entry|
      story = Story.from(entry) or next
      story.accession_numbers.each { |number| @index[[ story.collection, number ]] << story }
    end
  end

  # The stories about this record, each once, in the file's order
  def for(document)
    collections = Array(document["collection_ssim"]).map(&:to_s)
    numbers = Array(document["accession_number_ssim"]).map { |number| number.to_s.strip }
    collections.product(numbers).flat_map { |key| @index.fetch(key, []) }.uniq(&:url)
  end
end
