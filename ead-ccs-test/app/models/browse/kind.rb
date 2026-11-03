# frozen_string_literal: true

module Browse
  # A kind of entity a hub lists: the Solr field its values are in, the path segment, and the schema.org type of its pages.
  Kind = Data.define(:key, :field, :schema_type) do
    def self.all = Kind::ALL
    def self.find(key) = Kind::ALL.find { |kind| kind.key == key.to_s }
    def self.keys = Kind::ALL.map(&:key)

    # config/locales/browse.en.yml
    def plural = I18n.t("browse.kinds.#{key}.plural")
    def singular = I18n.t("browse.kinds.#{key}.singular")
    def blurb = I18n.t("browse.kinds.#{key}.blurb")
  end

  Kind::ALL = [
    Kind.new("creators", "creator_ssim", "Person"),
    Kind.new("places", "production_place_ssim", "Place"),
    Kind.new("subjects", "subject_ssim", "DefinedTerm")
  ].freeze
end
