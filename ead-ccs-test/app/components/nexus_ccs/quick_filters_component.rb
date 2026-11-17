# frozen_string_literal: true

module NexusCcs
  # One row of one-tap filters above the results: the most common values of era, object type and collection among the results on
  # the page, taken from the facet counts the page already has (no extra Solr request), in turn from each field so the row mixes
  # them. A value every result already has would not narrow anything and is left out, and so is a field the visitor has already chosen from. Each is a plain link to
  # the same search with that filter added, as the sidebar's own facet links are (Blacklight's search state). Nothing on an empty
  # page, nor when fewer than two values would help. A field the core does not have yet (date_era_ssim) simply adds nothing.
  class QuickFiltersComponent < ViewComponent::Base
    FIELDS = %w[date_era_ssim object_type_ssim collection_ssim].freeze
    PER_FIELD = 3
    MAX = 8
    MIN = 2

    Chip = Data.define(:field, :label, :item)

    def initialize(response:, search_state:)
      @response = response
      @search_state = search_state
    end

    def render? = @response.present? && total.positive? && chips.size >= MIN

    def total = @response.total.to_i

    def chips
      @chips ||= begin
        lists = FIELDS.map { |field| candidates(field) }
        lists.map(&:size).max.to_i.times.flat_map { |index| lists.filter_map { |list| list[index] } }.first(MAX)
      end
    end

    def path(chip)
      config = @search_state.blacklight_config.facet_fields[chip.field]
      helpers.search_action_path(@search_state.filter(config).add(chip.item).to_h)
    end

    def field_label(chip) = @search_state.blacklight_config.facet_fields[chip.field]&.label

    private

    def candidates(field)
      config = @search_state.blacklight_config.facet_fields[field]
      aggregation = @response.aggregations[field]
      return [] unless config && aggregation

      # A field with a value chosen already is left out: its values are alternatives (InclusiveFilterField), so another would widen
      # the results, not narrow them
      return [] if @search_state.filter(config).any?

      aggregation.items.reject { |item| item.hits.to_i >= total || item.hits.to_i.zero? }
                 .sort_by { |item| -item.hits.to_i }.first(PER_FIELD)
                 .map { |item| Chip.new(field: field, label: item.label.presence || item.value.to_s, item: item) }
    end
  end
end
