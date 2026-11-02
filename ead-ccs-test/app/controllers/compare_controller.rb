# frozen_string_literal: true

# Compare images side by side (CCS-58): the images of one record (/compare?record=ID) or the records the visitor has added from
# their pages (the session's CompareList), two to four panes each with its own OpenSeadragon viewer. Visitors have no login, so the
# list is the session's. What may be shown is decided here, each time, by RecordMedia (AccessPolicy and Sensitivity): a record
# that is withheld, or sensitive and not chosen by this visitor, cannot be added, and is left out of the page if it was added before.
class CompareController < ApplicationController
  include RecordLookup

  layout "pages"

  Pane = Data.define(:record_id, :title, :accession_number, :licence, :images, :index)

  MIN_PANES = 2

  def show
    if params[:record].present?
      @record_mode = true
      @panes, @record_title = record_panes(params[:record].to_s)
    else
      @panes, @unavailable = list_panes
    end
    @panes_count = @panes.size
  end

  def create
    document = find_record(params[:id])
    media = RecordMedia.for(document, session: session)
    return back_with(document, alert: t("nexus_ccs.compare.not_available")) unless media.shown? && media.images.any?

    if list.add(document.id)
      back_with(document, notice: t("nexus_ccs.compare.added", title: media.title))
    else
      back_with(document, alert: t("nexus_ccs.compare.full", count: CompareList::MAX))
    end
  end

  def destroy
    list.remove(params[:id])
    if params[:return_to] == "record"
      redirect_to solr_document_path(params[:id], anchor: "digital-assets"), notice: t("nexus_ccs.compare.removed"), status: :see_other
    else
      redirect_to compare_path, notice: t("nexus_ccs.compare.removed"), status: :see_other
    end
  end

  def clear
    list.clear
    redirect_to compare_path, notice: t("nexus_ccs.compare.cleared"), status: :see_other
  end

  private

  def list = @list ||= CompareList.new(session)

  # One record's images, as many panes as asked (2 to 4, and no more than it has images); a record with nothing to show is a 404
  def record_panes(id)
    document = find_record(id)
    media = RecordMedia.for(document, session: session)
    images = media.images
    raise ActionController::RoutingError, "Not Found" if images.empty?

    count = params[:panes].to_i.clamp(MIN_PANES, CompareList::MAX).clamp(1, images.size)
    [ Array.new(count) { |index| pane(document, media, images, index % images.size) }, media.title ]
  end

  # The records in the list that may still be shown, in the order added; the number that could not be
  def list_panes
    asked = list.ids
    documents = find_records(asked)
    panes = documents.filter_map do |document|
      media = RecordMedia.for(document, session: session)
      images = media.images
      pane(document, media, images, 0) if images.any?
    end
    kept = panes.map(&:record_id)
    list.replace(kept) if kept != asked
    [ panes, asked.size - panes.size ]
  end

  def pane(document, media, images, index)
    Pane.new(record_id: document.id.to_s, title: media.title, accession_number: media.accession_number, licence: media.licence,
             images: images, index: index)
  end

  def back_with(document, **flash_options)
    redirect_to solr_document_path(document.id, anchor: "digital-assets"), status: :see_other, **flash_options
  end
end
