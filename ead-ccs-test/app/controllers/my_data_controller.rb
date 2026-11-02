# frozen_string_literal: true

# Delete my data (CCS-148): shows a visitor what the site holds against their cookie (saved records, lists, saved searches,
# search history, choices about sensitive records, the guest user row) and removes it on request. The page is the
# confirmation: nothing is removed by opening it, only by the button. Access requests are NOT removed: they are records
# the University must action and keep, and have their own contact route (the privacy page says so). Behind the same
# saved-records switch as the data it removes (config/routes.rb).
class MyDataController < ApplicationController
  layout "pages"

  before_action { response.headers["Cache-Control"] = "no-store" }

  def show
    @held = MyData.new(session).counts
  end

  def destroy
    MyData.new(session).delete!
    redirect_to my_data_path, notice: t("nexus_ccs.my_data.deleted")
  end
end
