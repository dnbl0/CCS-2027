# frozen_string_literal: true

# Visitors never log in: Blacklight's own guest-user support (current_or_guest_user) owns their bookmarks, keyed by
# the session cookie (kept 30 days, config/initializers/session_store.rb). Two small differences from the gem's
# default, so that browsing does not write to the database:
#  - there is no authentication provider, so we say there is one (the guest) and that nobody is signed in;
#  - guest_user finds the visitor's row but does not create one; a new, unsaved User stands in until the first
#    record is saved (BookmarksController saves it then). Crawlers and first-time visitors leave no rows.
module GuestBookmarks
  extend ActiveSupport::Concern

  # Number of saved records for the header bar, without creating a guest.
  # (The header asks on every page: a database that is down must not take the pages that do not need it down too, so it says 0.)
  def saved_records_count
    id = session[:blacklight_guest_user_id]
    id ? Bookmark.where(user_id: id, user_type: "User").count : 0
  rescue ActiveRecord::ActiveRecordError, PG::Error => e
    Rails.logger.warn("Saved records count unavailable: #{e.class}")
    0
  end

  private

  def has_user_authentication_provider? = true

  def current_user = nil

  def guest_user
    @blacklight_guest_user ||= find_blacklight_guest_user || User.new
  end
end
