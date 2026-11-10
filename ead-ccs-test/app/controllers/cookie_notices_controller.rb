# frozen_string_literal: true

# Saves the visitor's answer to the cookie notice (CCS-471, CookieNotice) in one first-party cookie. Works without JavaScript (a
# form post that goes back to the page); with it, cookie_notice_controller.js posts the same form and gets 204. Nothing else is
# stored: no row, no session value, no address.
class CookieNoticesController < ApplicationController
  def create
    choice = params[:choice].to_s
    if CookieNotice.accepted_choices.include?(choice)
      cookies[CookieNotice::COOKIE] = {
        value: CookieNotice.value(choice),
        expires: CookieNotice::LIFETIME.from_now,
        httponly: true,
        same_site: :lax,
        secure: request.ssl?
      }
    end

    if request.format.json?
      head :no_content
    else
      redirect_back_or_to root_path, allow_other_host: false, status: :see_other
    end
  end
end
