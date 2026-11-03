# frozen_string_literal: true

# A search a visitor chose to keep from their search history (CCS-130). It holds a copy of the search's parameters
# (the same hash Blacklight's Search stores), so the link back to the results page is always built from what was saved.
class SavedSearch < ApplicationRecord
  NAME_LIMIT = 120
  # A visitor keeps at most this many (the saved searches page lists them all, so it must stay bounded)
  MAX_PER_USER = 100

  belongs_to :user

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :query_params, presence: true
  validate :user_has_room, on: :create

  # Newest first, as the saved searches page lists them
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  # The name given to a saved search when the visitor does not type one: its terms, then its filters, as
  # "skull · Grainger Museum, With a digital asset". A search with neither is "All records". Cut to NAME_LIMIT.
  # params: the search's parameters (string keys, e.g. "q", "f" => { "collection_ssim" => [...] }, "clause" for Advanced search)
  def self.default_name(params)
    params = params.to_h.deep_stringify_keys
    name = [ terms(params).join(" "), filters(params).join(", ") ].compact_blank.join(" · ")

    (name.presence || "All records").truncate(NAME_LIMIT)
  end

  # The words searched for: the search box, or each Advanced search clause's words
  def self.terms(params)
    clauses = params["clause"].is_a?(Hash) ? params["clause"].values.filter_map { |clause| clause["query"] if clause.is_a?(Hash) } : []

    [ params["q"], *clauses ].compact_blank.map { |term| term.to_s.squish }
  end

  # What the search is narrowed to: each filter's values, and a year range as "1900–1950"
  def self.filters(params)
    values = %w[f f_inclusive].flat_map do |key|
      params[key].is_a?(Hash) ? params[key].flat_map { |field, chosen| Array(chosen).map { |value| filter_label(field, value) } } : []
    end
    years = params["range"].is_a?(Hash) ? params["range"].values.filter_map { |range| year_range(range) } : []

    values + years
  end

  # The Digital asset filter stores "with"; the page says "With a digital asset"
  def self.filter_label(field, value)
    return "With a digital asset" if field == SearchDefaults::DIGITAL_ASSET_FIELD && value == "with"

    value.to_s.squish
  end

  def self.year_range(range)
    return unless range.is_a?(Hash)

    from, to = range.values_at("begin", "end").map(&:presence)
    [ from, to ].compact.join("–") if from || to
  end

  private_class_method :terms, :filters, :filter_label, :year_range

  # What the results page needs to repeat the search
  def search_params = query_params.to_h.symbolize_keys

  # Saves the search once, however many times the request arrives (a double click, a second tab, a retry): under a lock on the
  # visitor's row, the same name and parameters are found, not made again. Returns the saved search (check persisted?).
  def self.keep(user, name:, query_params:)
    user.with_lock { user.saved_searches.find_by(name: name, query_params: query_params) || user.saved_searches.create(name: name, query_params: query_params) }
  end

  private

  def user_has_room
    errors.add(:base, :too_many_saved_searches, count: MAX_PER_USER) if user && user.saved_searches.count >= MAX_PER_USER
  end
end
