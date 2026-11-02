# frozen_string_literal: true

module NexusCcs
  # Says why a record's digital asset can't be downloaded (:view_only) or isn't shown (:request), and links to the
  # request form (AccessPolicy, CCS-67, CCS-69). Renders nothing for an :open record. Plain text with a link, not a
  # live region or alert: it is on the page when it loads and doesn't change. The wording is in
  # config/locales/en.yml (nexus_ccs.access_notice). Light card so it reads on the dark media band as well as on the page.
  class AccessNoticeComponent < ViewComponent::Base
    def initialize(document:)
      @document = document
      @tier = AccessPolicy.tier(document)
    end

    attr_reader :tier

    def render? = tier != :open

    def title = t("nexus_ccs.access_notice.#{tier}.title")
    def body = t("nexus_ccs.access_notice.#{tier}.body")
    def link_text = t("nexus_ccs.access_notice.#{tier}.link")
    def request_path = AccessPolicy.request_path(@document)
  end
end
