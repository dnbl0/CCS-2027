# frozen_string_literal: true

# Adds a record to one of the visitor's lists, and takes it out again (CCS-389). Both go back to the page they were asked
# from, where the notice is announced. The ids are Solr document ids; a record is not checked against Solr, as a Bookmark is not.
class ListItemsController < ApplicationController
  include GuestLists

  def create
    list = visitor_lists.find_by(id: params[:list_id])
    return back_or_to_lists(alert: t("nexus_ccs.lists.not_found")) unless list

    item = list.list_items.build(document_id: params[:document_id].to_s)
    if item.save
      back_or_to_lists(notice: t("nexus_ccs.lists.added", name: list.name))
    elsif item.errors.of_kind?(:document_id, :taken)
      back_or_to_lists(notice: t("nexus_ccs.lists.already_in", name: list.name))
    else
      back_or_to_lists(alert: t("nexus_ccs.lists.failure", reason: item.errors.full_messages.to_sentence))
    end
  end

  def destroy
    list = visitor_lists.find_by(id: params[:list_id])
    item = list&.list_items&.find_by(id: params[:id])
    return back_or_to_lists(alert: t("nexus_ccs.lists.not_found")) unless item

    item.destroy
    back_or_to_lists(notice: t("nexus_ccs.lists.removed", name: list.name))
  end
end
