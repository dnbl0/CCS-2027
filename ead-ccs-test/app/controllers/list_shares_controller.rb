# frozen_string_literal: true

# Sharing one of the visitor's lists as a gallery: create the link, make a new one (the old stops working), or stop sharing. Only
# the list's owner (the guest user of the cookie) can; anyone else's list is "not found". Each goes back to the list, where the
# share dialog is opened to show the result. The public page is GalleriesController.
class ListSharesController < ApplicationController
  include GuestLists

  before_action :find_list

  def create
    @list.share!
    redirect_to list_path(@list, share: 1), notice: t("nexus_ccs.galleries.share.created")
  end

  def regenerate
    @list.share!(regenerate: true)
    redirect_to list_path(@list, share: 1), notice: t("nexus_ccs.galleries.share.regenerated")
  end

  def destroy
    @list.unshare!
    redirect_to list_path(@list), notice: t("nexus_ccs.galleries.share.stopped")
  end

  private

  def find_list
    @list = visitor_lists.find_by(id: params[:list_id])
    redirect_to lists_path, alert: t("nexus_ccs.lists.not_found") unless @list
  end
end
