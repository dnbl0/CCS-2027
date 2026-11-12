# frozen_string_literal: true

module NexusCcs
  # The two round previous / next buttons of the viewer layout (?layout=viewer): under the Highlights cards and under each row of More
  # like this. Which row they scroll, and the disabled ends, are the page controller's (viewer_page_controller.js).
  class ViewerChevronsComponent < ViewComponent::Base
    def initialize(back_label:, forward_label:, back_data: {}, forward_data: {}, back_disabled: false, extra_class: nil)
      @back_label = back_label
      @forward_label = forward_label
      @back_data = back_data
      @forward_data = forward_data
      @back_disabled = back_disabled
      @extra_class = extra_class
    end

    attr_reader :back_label, :forward_label, :back_data, :forward_data, :extra_class

    def back_disabled? = @back_disabled

    def classes = [ "viewer-chevrons", extra_class ].compact.join(" ")
  end
end
