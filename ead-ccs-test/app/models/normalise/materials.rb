# frozen_string_literal: true

module Normalise
  # The Materials / Medium filter's terms from material_ssim's combined values: "paper, ink" gives "paper" and "ink", "oil on canvas"
  # gives "oil" and "canvas". Split on commas, semicolons, " and " and " on ", trimmed and lower-cased; config/materials.yml has the
  # stop list and the synonyms (placeholder, for the collections team).
  module Materials
    CONFIG = Rails.root.join("config/materials.yml")
    SPLIT = /\s*[,;]\s*|\s+and\s+|\s+on\s+/i

    def self.config = (@config ||= YAML.safe_load_file(CONFIG).freeze)
    def self.reload! = @config = nil

    # values: material_ssim's values. Returns the terms, in order, each once.
    def self.terms(values)
      stop = Array(config["stop"]).map(&:to_s)
      synonyms = config["synonyms"] || {}
      Array(values).flat_map { |value| value.to_s.split(SPLIT) }
                   .map { |term| term.downcase.squish.delete_suffix(".").strip }
                   .reject { |term| term.empty? || stop.include?(term) }
                   .map { |term| synonyms.fetch(term, term) }
                   .uniq
    end
  end
end
