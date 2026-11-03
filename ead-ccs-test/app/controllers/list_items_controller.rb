# frozen_string_literal: true

# Adds a record to one of the visitor's lists, and takes it out again (CCS-389). Both go back to the page they were asked
# from, where the notice is announced. The ids are Solr document ids; a record is not checked against Solr, as a Bookmark is not.
class ListItemsController < ApplicationController
  include GuestLists

  def create
    list = visitor_lists.find_by(id: params[:list_id])
    return back_or_to_lists(alert: t("nexus_ccs.lists.not_found")) unless list
    return add_several(list, Array(params[:document_ids])) if params[:document_ids].present?

    item = list.list_items.build(document_id: params[:document_id].to_s)
    if item.save
      back_or_to_lists(notice: t("nexus_ccs.lists.added", name: list.name))
    elsif item.errors.of_kind?(:document_id, :taken)
      back_or_to_lists(notice: t("nexus_ccs.lists.already_in", name: list.name))
    else
      back_or_to_lists(alert: t("nexus_ccs.lists.failure", reason: item.errors.full_messages.to_sentence))
    end
  rescue ActiveRecord::RecordNotUnique # two requests at once: the unique index let one in
    back_or_to_lists(notice: t("nexus_ccs.lists.already_in", name: list.name))
  end

  def destroy
    list = visitor_lists.find_by(id: params[:list_id])
    item = list&.list_items&.find_by(id: params[:id])
    return back_or_to_lists(alert: t("nexus_ccs.lists.not_found")) unless item

    item.destroy
    back_or_to_lists(notice: t("nexus_ccs.lists.removed", name: list.name))
  end

  private

  # The selected records (CCS-40), added in one go: each once, those already in the list left as they are, stopping if the list fills
  def add_several(list, document_ids)
    added = 0
    document_ids.grep(String).first(Selection::MAX).each do |document_id|
      item = list.list_items.build(document_id: document_id)
      if item.save
        added += 1
      elsif !item.errors.of_kind?(:document_id, :taken)
        return back_or_to_lists(alert: t("nexus_ccs.lists.failure", reason: item.errors.full_messages.to_sentence))
      end
    end
    back_or_to_lists(notice: t("nexus_ccs.lists.added_several", count: added, name: list.name))
  end
end
