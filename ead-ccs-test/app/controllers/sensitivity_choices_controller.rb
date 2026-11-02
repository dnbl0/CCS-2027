# frozen_string_literal: true

# The visitor's choice, on a record whose digital assets are sensitive, to view them or not (CCS-227). It is a form post so it
# works without JavaScript; the choice is kept in the session (Sensitivity::Choices) and the record page is shown again.
# A record that is not sensitive, or whose assets are withheld (AccessPolicy :request), has nothing to choose.
class SensitivityChoicesController < ApplicationController
  include RecordLookup

  def create
    document = find_record(params[:id])
    raise ActionController::RoutingError, "Not Found" unless Sensitivity.sensitive?(document) && AccessPolicy.view?(document)

    Sensitivity::Choices.new(session).record(document.id, params[:choice])
    flash[:sensitivity_chosen] = true
    redirect_to solr_document_path(document.id, anchor: "digital-assets"), status: :see_other
  end
end
