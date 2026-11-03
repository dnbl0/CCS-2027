# frozen_string_literal: true

require "digest"

module Browse
  # The address of an entity: "grainger-percy-aldridge-3f9a2c41be". The last part is a hash of the value's folded spelling, the
  # words before it are only for people and search engines.
  #
  #   deterministic   the same value always gives the same slug, with no table: a link can be built from a record alone
  #   collision-safe  the hash tells values apart that read alike ("Hirschfeld-Mack" and "Hirschfeld Mack" are one entity by
  #                   design (Browse::Index folds them), "Smith, J" and "Smith J." too); the readable part never decides
  #   reversible      Index#find_by_slug looks the hash up in the value list and sends a stale or mistyped readable part
  #                   to the right address (301); an unknown hash is a 404
  #   safe            a slug is letters, digits and hyphens: it is never put in a Solr query, the value found by it is
  module Slug
    TOKEN_LENGTH = 10
    READABLE_LENGTH = 60
    PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

    # The spelling variants of one entity share this: case, accents, brackets and "(?)" marks do not matter.
    #   "Portraits" / "portraits"; "Europe (?)" / "Europe"; "[London]" / "London"; "Hirschfeld-Mack, Ludwig" / "Hirschfeld Mack, Ludwig"
    def self.fold(value)
      folded = I18n.transliterate(value.to_s).downcase
      folded = folded.gsub(/[\[(]\s*\?\s*[\])]/, " ")
      folded.gsub(/[^a-z0-9]+/, " ").squish.presence || value.to_s.downcase.squish
    end

    def self.token(kind_key, value) = Digest::SHA256.hexdigest("#{kind_key}:#{fold(value)}")[0, TOKEN_LENGTH]

    def self.readable(value)
      I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "").first(READABLE_LENGTH).chomp("-")
    end

    def self.build(kind_key, value)
      [ readable(value).presence || kind_key.to_s.singularize, token(kind_key, value) ].join("-")
    end

    # [readable words, token] of a slug, or nil if it is not one
    def self.parse(slug)
      slug = slug.to_s
      return unless slug.match?(PATTERN)

      readable, _, token = slug.rpartition("-")
      [ readable, token ] if token.match?(/\A\h{#{TOKEN_LENGTH}}\z/)
    end
  end
end
