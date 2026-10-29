# frozen_string_literal: true

# The text of the browse collections page and of the collection landing pages (config/pages.yml).
module SitePages
  PATH = Rails.root.join("config/pages.yml")
  MENU_ORDER = %w[grainger-museum harry-brookes-allen-museum henry-forman-atkinson-dental-museum medical-history-museum university-art-collection].freeze

  class << self
    def browse = data.fetch("browse")

    # The landing page data of a collection, by slug; nil for an unknown one
    def collection(slug) = data.fetch("collections")[slug]

    def slugs = data.fetch("collections").keys

    # The collections in the order of the header menu (alphabetical by label): [menu label, Solr collection_ssim value, slug]
    def menu = MENU_ORDER.map { |slug| c = collection(slug); [ c["menu_label"], c["facet_value"], slug ] }

    private

    def data = @data ||= YAML.load_file(PATH).freeze
  end
end
