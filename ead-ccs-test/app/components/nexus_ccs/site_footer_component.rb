# frozen_string_literal: true

module NexusCcs
  # University of Melbourne footer: acknowledgement of Country, links, contact and legal bar.
  class SiteFooterComponent < Blacklight::Component
    def about_links = SiteNavigation::FOOTER_ABOUT
    def social_links = SiteNavigation::FOOTER_SOCIAL
    def site_links = SiteNavigation::FOOTER_SITE
    def legal_links = SiteNavigation::FOOTER_LEGAL
    def identifiers = SiteNavigation::FOOTER_IDENTIFIERS
  end
end
