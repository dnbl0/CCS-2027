# frozen_string_literal: true

module NexusCcs
  # On a record page whose displayed text has terms from the de-bias list (DebiasTerms): says so near the title, shows each term in
  # its context with the explanation, and links to "About the language in our records" and the contact card. It changes nothing: the
  # record's text is shown as it is held (RecordDebias marks the term where the field shows it). Nothing renders when nothing was
  # found, and the list ships with no real terms. Same placement and tone as the cultural protocols notice. PLACEHOLDER wording
  # (config/locales/debias.en.yml) until the collections team and Indigenous advisers approve it.
  #
  # matches: DebiasTerms::Match list for the text the page displays (never other fields, so a withheld field cannot leak);
  # labels: { solr field => the label the details list gives it }
  class DebiasNoticeComponent < ViewComponent::Base
    MAX_ENTRIES = 8
    MAX_CONTEXTS = 2

    Item = Struct.new(:entry, :contexts, keyword_init: true)
    Context = Struct.new(:field_label, :before, :found, :after, keyword_init: true)

    def initialize(matches:, labels: {})
      @matches = matches
      @labels = labels
    end

    def render? = @matches.any?

    # One item per list entry, in the order the page shows them; at most MAX_ENTRIES
    def items
      @items ||= @matches.group_by(&:entry).first(MAX_ENTRIES).map do |entry, found|
        contexts = found.uniq { |match| [ match.field, match.found.downcase ] }.first(MAX_CONTEXTS).map do |match|
          before, term, after = match.context
          Context.new(field_label: @labels[match.field] || t("nexus_ccs.debias.field_fallback"), before: before, found: term, after: after)
        end
        Item.new(entry: entry, contexts: contexts)
      end
    end

    def more = @matches.map(&:entry).uniq.size - items.size

    def severity(entry) = t("nexus_ccs.debias.severity.#{entry.severity}")
  end
end
