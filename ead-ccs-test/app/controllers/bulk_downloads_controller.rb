# frozen_string_literal: true

require "tempfile"

# Downloading the digital assets of several selected records as one zip (CCS-167), from the saved records page or one of the
# visitor's lists. Two steps, both form posts, so it works without JavaScript:
#   review  the plan: what goes in, what is left out and why, and whether it is within the limits (BulkDownload)
#   create  the zip itself, planned again from the ids (the review page is not trusted), as a file download
# Behind config.x.saved_records with the pages that select the records (routes). BulkDownload decides what may go in.
class BulkDownloadsController < ApplicationController
  include RecordLookup
  include Blacklight::SearchContext # the header's Search results link goes back to the visitor's last search

  layout "pages"

  # Where "back" goes: only the pages that select records
  RETURN_TO = %r{\A/(bookmarks|lists/\d+)\z}

  before_action :load_selection

  def review
    @download = plan
    flash.now[:alert] = limit_message(@download.limit_problem) if @download.limit_problem
  end

  def create
    download = plan
    return redirect_to(@return_to, alert: t("nexus_ccs.bulk_download.nothing"), status: :see_other) unless download.downloadable?

    file = Tempfile.new([ "ccs-assets", ".zip" ], binmode: true)
    download.write_zip(file, persistent_link: ->(document) { solr_document_url(document) })
    # The request keeps the file until the response has been sent; Tempfile removes it when it is collected
    request.env["ccs.bulk_download.tempfile"] = file
    send_file file.path, type: "application/zip", disposition: "attachment", filename: BulkDownload.filename
  end

  private

  def load_selection
    @return_to = params[:return_to].to_s.match?(RETURN_TO) ? params[:return_to].to_s : bookmarks_path
    @ids = Array(params[:ids]).map(&:to_s).compact_blank.uniq
    if @ids.empty?
      redirect_to @return_to, alert: t("nexus_ccs.bulk_download.none_chosen"), status: :see_other
    elsif @ids.size > BulkDownload::MAX_RECORDS
      redirect_to @return_to, alert: t("nexus_ccs.bulk_download.too_many_records", count: BulkDownload::MAX_RECORDS), status: :see_other
    end
  end

  # A record no longer in the index is reported (as not found), not hidden
  def plan
    records = find_records(@ids)
    documents = @ids.map { |id| records.find { |document| document.id.to_s == id } }
    viewing = Sensitivity::Choices.new(session)
    BulkDownload.new(documents, may_view_sensitive: ->(document) { viewing.viewing?(document.id) })
  end

  def limit_message(problem)
    t("nexus_ccs.bulk_download.#{problem}", files: BulkDownload::MAX_FILES, size: helpers.number_to_human_size(BulkDownload::MAX_BYTES))
  end
end
