# frozen_string_literal: true

module NexusCcs
  # The one navy pill button of the viewer layout, in the local navigation (nav: true) and in the pill card: Download image for an open
  # record (its href follows the image the hero shows, viewer_page_controller.js), Request access for a withheld one, Contact us for any
  # other (RecordViewerComponent#primary).
  class ViewerPrimaryComponent < ViewComponent::Base
    def initialize(primary:, new_tab:, nav:)
      @primary = primary
      @new_tab = new_tab
      @nav = nav
    end

    attr_reader :primary

    def new_tab? = @new_tab
    def css = @nav ? "viewer-nav__button" : "viewer-pillcard__button"
    def download? = primary[:kind] == :download
  end
end
