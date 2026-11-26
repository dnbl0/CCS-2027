# frozen_string_literal: true

# The one "cannot be shown right now" sentence (docs/ux-drift-audit.md B10): every page and part of a page that Solr cannot answer says the
# same thing in the same words, "<what> cannot be shown right now. Please try again in a few minutes", with a way on where there is one.
module UnavailableHelper
  # what: the subject ("This page", "The colours", "The list of makers"); search: a path to its records in the search, or nil
  def unavailable_sentence(what = t("nexus_ccs.unavailable.this_page"), search: nil)
    return t("nexus_ccs.unavailable.sentence", what: what) unless search

    t("nexus_ccs.unavailable.sentence_with_search_html", what: what, link: link_to(t("nexus_ccs.unavailable.search"), search))
  end

  # The sentence as its own paragraph, in its one style
  def unavailable_note(what = t("nexus_ccs.unavailable.this_page"), search: nil)
    tag.p(unavailable_sentence(what, search: search), class: "unavailable-note")
  end
end
