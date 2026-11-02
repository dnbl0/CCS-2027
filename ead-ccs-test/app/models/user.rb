# frozen_string_literal: true

# A visitor, identified only by their session cookie (no login). Blacklight's User concern gives it
# `bookmarks`, `searches` and the bookmark helpers; a row is created the first time a record is saved
# (see BookmarksController#remember_guest_user).
class User < ApplicationRecord
  include Blacklight::User

  has_many :saved_searches, dependent: :destroy

  def to_s = "Guest #{id}"
end
