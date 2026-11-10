# frozen_string_literal: true

module NexusCcs
  # The cookie notice for every visitor (CCS-471; nobody signs in, so every visitor is a guest). A non-modal region at the top
  # of the page, in the page's flow so nothing moves when it loads: it says which cookies the site sets and why, links to the full
  # list on /privacy, and records the answer through CookieNotice (CookieNoticesController).
  #
  # Today every cookie is essential and the site sets no optional one, so the notice says exactly that and has one button
  # ("OK"), not a choice. With optional categories (CookieNotice::OPTIONAL) it lists them and shows "Decline" and "Accept" as
  # two buttons of the same kind, in that order, with nothing set before "Accept". It is not a dialog: it takes no focus on load,
  # traps none and has no backdrop (controllers/cookie_notice_controller.js sends focus to the main content when it is answered).
  # All wording is PLACEHOLDER wording until the University approves it (config/locales/cookie_notice.en.yml).
  class CookieNoticeComponent < ViewComponent::Base
    def essential = CookieNotice.essential

    def optional = CookieNotice.optional

    def choosable? = CookieNotice.choosable?
  end
end
