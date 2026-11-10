# frozen_string_literal: true

# The one rule for whether a record's image may appear on a page that is not the record's own: a shared gallery, an embed, an
# oEmbed response. The same as the result card's: the thumbnail only when the tier lets the asset be viewed (AccessPolicy) and the
# record is not sensitive (Sensitivity). A visitor's choice to view a sensitive record is made on the record page and kept in
# their cookie, so it is deliberately not honoured here: an embed or a link read by someone else must not carry it.
module SharedMedia
  # document: a SolrDocument. The site-relative path of the thumbnail
  # (with a version token, AssetVersion), or nil.
  def self.thumbnail_path(document)
    path = document["thumbnail_path_ssi"].presence
    AssetVersion.url(path) if path && AccessPolicy.view?(document) && !Sensitivity.sensitive?(document)
  end

  # Why a record has no image here: :request (withheld by its tier), :sensitive, or nil (it has an image, or never had one)
  def self.withheld_reason(document)
    if AccessPolicy.tier(document) == :request then :request
    elsif Sensitivity.sensitive?(document) then :sensitive
    end
  end
end
