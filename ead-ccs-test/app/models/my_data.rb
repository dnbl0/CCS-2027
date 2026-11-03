# frozen_string_literal: true

# What the site holds against one visitor's session cookie, and its removal (CCS-148, MyDataController). The visitor is the
# guest user of the cookie (GuestBookmarks); the search history is the rows of `searches` whose ids the session lists.
#
# Removed: saved records, lists (and their records, and so any share link: a gallery is a 404 from then on), saved searches, the guest user row, the search history rows, and the
# session's history, sensitivity choices and recently viewed list. Kept: access requests (records the University must action; the session's list of
# the visitor's own requests stays so they can still open a confirmation).
class MyData
  SESSION_KEYS = %i[blacklight_guest_user_id history sensitivity_choices recently_viewed].freeze

  def initialize(session)
    @session = session
  end

  # { saved_records:, lists:, shared_lists:, saved_searches:, searches:, sensitivity_choices:, recently_viewed: } as counts
  def counts
    {
      saved_records: user_id ? Bookmark.where(user_id: user_id, user_type: "User").count : 0,
      lists: user_id ? List.where(user_id: user_id).count : 0,
      shared_lists: user_id ? List.where(user_id: user_id).where.not(share_token: nil).count : 0,
      saved_searches: user_id ? SavedSearch.where(user_id: user_id).count : 0,
      searches: history_ids.size,
      sensitivity_choices: Sensitivity::Choices::KEY.then { |key| @session[key].is_a?(Hash) ? @session[key].size : 0 },
      recently_viewed: RecentlyViewed.new(@session).ids.size
    }
  end

  def any? = counts.values.any?(&:positive?)

  def delete!
    ActiveRecord::Base.transaction do
      if user_id
        Bookmark.where(user_id: user_id, user_type: "User").delete_all
        SavedSearch.where(user_id: user_id).delete_all
        List.where(user_id: user_id).destroy_all # list_items go with their list
        Search.where(user_id: user_id, user_type: "User").delete_all
        User.where(id: user_id).delete_all
      end
      Search.where(id: history_ids).delete_all
    end
    SESSION_KEYS.each { |key| @session.delete(key) }
  end

  private

  def user_id = @session[:blacklight_guest_user_id]

  def history_ids = Array(@session[:history]).map(&:to_i)
end
