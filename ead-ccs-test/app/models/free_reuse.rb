# frozen_string_literal: true

# The "Open licence (public domain)" switch: records with an asset a visitor may view AND download (AccessPolicy tier :open: for
# a record with DAM data, at least one open asset). It is a search filter (the facet field `free_reuse`, value `open`: ?f[free_reuse][]=open), so it is a removable pill, it is
# kept in search history and saved searches, and the "Why am I seeing these results?" panel can take it off.
#
# The filter is built from AccessPolicy (its :open licences and its withheld access conditions), not from a list of its own, so it
# is the same rule as the download button. A record with several licences is :open only when EVERY licence is an open one (the most
# restrictive tier wins), so the filter asks for "has an open licence" and "has no licence that is not an open one". Solr cannot say
# "a value that is not one of these" directly, so the second part is the ranges of licence_type_ssim between the open values.
# Records with no licence are :view_only (AccessPolicy), so they are not matched.
#
# When the DAM classification replaces AccessPolicy.tier, re-derive .filter_query from it (the live test in
# test/models/free_reuse_test.rb fails if the two disagree).
#
# The wording is PLACEHOLDER: "free to reuse" would be a legal claim (it ignores moral rights, cultural protocols and other
# restrictions), so the visible label is the neutral "Open licence (public domain)" until the University approves a statement.
module FreeReuse
  FIELD = "free_reuse"
  VALUE = "open"
  LICENCE_FIELD = "licence_type_ssim"
  ACCESS_CONDITION_FIELD = "access_condition_ssi"

  # The facet query (config.add_facet_field query:) the switch applies and counts
  def self.query_config
    { VALUE.to_sym => { label: I18n.t("nexus_ccs.free_reuse.label"), fq: filter_query } }
  end

  # The record's tier, as AccessPolicy decided it from the DAM's licences when the DAM sync wrote the record (Dam::SolrWriter): the
  # most permissive of its assets' own tiers, after the EMu restrictions
  DAM_TIER_FIELD = "dam_access_tier_ssi"

  # The Solr filter query for tier :open, as text. A record with DAM data is open when the DAM sync found it so (DAM_TIER_FIELD:
  # the DAM is the source of truth for usage rights), which means it has at least one open asset (it may have others that are
  # view only or withheld); a record without is judged by its EMu licence, as before.
  def self.filter_query
    emu = emu_filter_query
    dam = "#{DAM_TIER_FIELD}:open"
    emu ? "#{dam} OR (-#{DAM_TIER_FIELD}:[* TO *] #{emu})" : dam
  end

  # The EMu rule, or nil when no EMu licence is open. The index keeps licences as written ("Public domain - Copyright expired"),
  # AccessPolicy compares them in lower case, so the usual spellings of each open licence are all taken as open.
  def self.emu_filter_query
    open = spellings(AccessPolicy.licences_with_tier(:open))
    return nil if open.empty?

    parts = [ "#{LICENCE_FIELD}:(#{open.map { |value| SolrQuery.phrase(value) }.join(' ')})",
              "-#{LICENCE_FIELD}:(#{gaps(open).join(' ')})" ]
    withheld = spellings(AccessPolicy.withheld_access_conditions)
    parts << "-#{ACCESS_CONDITION_FIELD}:(#{withheld.map { |value| SolrQuery.phrase(value) }.join(' ')})" if withheld.any?
    parts.join(" ")
  end

  # Every licence that is not an open one, as the ranges of terms between (and around) the open values
  def self.gaps(open)
    bounds = [ nil, *open, nil ]
    bounds.each_cons(2).map do |low, high|
      "#{low ? "{#{SolrQuery.phrase(low)}" : '[*'} TO #{high ? "#{SolrQuery.phrase(high)}}" : '*]'}"
    end
  end

  # Lower case, Capitalised (the whole value, and each part of "A - B"), Title Case and UPPER CASE, without duplicates and in the
  # order Solr sorts terms. The index keeps "Public domain - Copyright expired": the second part starts with a capital.
  def self.spellings(values)
    values.flat_map do |value|
      [ value, value.capitalize, value.sub(/\A./, &:upcase), value.split(" - ").map { |part| part.sub(/\A./, &:upcase) }.join(" - "),
        value.gsub(/\b[a-z]/, &:upcase), value.upcase ]
    end.uniq.sort
  end

  private_class_method :emu_filter_query, :gaps, :spellings
end
