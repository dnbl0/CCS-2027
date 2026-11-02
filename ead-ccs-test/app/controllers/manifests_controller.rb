# frozen_string_literal: true

# A record's images as an IIIF Presentation 3.0 manifest, /catalog/:id/manifest.json (CCS-57), for external viewers (Mirador,
# Universal Viewer). It answers only what the record page would show the same visitor: a record whose assets are withheld
# (AccessPolicy :request), has no image the manifest can draw, or is sensitive and not chosen by this visitor is a 404, as if there were no
# manifest, so nothing of it leaks. Not an ApplicationController: it is data, with no layout, no guest user and no browser check.
#
# Caching and CORS (docs/media-viewer.md): an ordinary record's manifest is the same for everyone, so it is public, cached for an hour
# and open to any origin (Access-Control-Allow-Origin: *, as the IIIF spec recommends, so a viewer on another site can read it).
# A sensitive record the visitor chose to view depends on their session cookie: it is private, never stored, and has no CORS header
# (a viewer on another origin sends no cookie, so it would get the 404 anyway).
class ManifestsController < ActionController::Base
  include RecordLookup

  CONTENT_TYPE = %(application/ld+json;profile="#{IiifManifest::CONTEXT}").freeze

  def show
    document = find_record(params[:id])
    media = RecordMedia.for(document, session: (session if Sensitivity.sensitive?(document)))
    manifest = IiifManifest.new(media, base_url: request.base_url)
    raise ActionController::RoutingError, "Not Found" unless media.shown? && manifest.any?

    if media.sensitive?
      response.headers["Cache-Control"] = "private, no-store"
    else
      expires_in 1.hour, public: true
      response.headers["Access-Control-Allow-Origin"] = "*"
    end
    render body: manifest.as_json.to_json, content_type: CONTENT_TYPE
  end
end
