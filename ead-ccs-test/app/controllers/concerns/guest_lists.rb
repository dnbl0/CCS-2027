# frozen_string_literal: true

# The named lists (CCS-389) belong to the visitor's guest user, found by the session cookie (see GuestBookmarks). Browsing
# creates no row: the guest is created on the first list, or the first record added to one.
module GuestLists
  extend ActiveSupport::Concern

  private

  def visitor_lists
    id = session[:blacklight_guest_user_id]
    id ? List.where(user_id: id) : List.none
  end

  def guest_owner
    user = current_or_guest_user
    user.save! unless user.persisted?
    session[:blacklight_guest_user_id] = user.id
    user
  end

  # Back to the page the request came from (a results page, a record, a list), or the lists page
  def back_or_to_lists(**flash)
    redirect_back_or_to lists_path, allow_other_host: false, **flash
  end
end
