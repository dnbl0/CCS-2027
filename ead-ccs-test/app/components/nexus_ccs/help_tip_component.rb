# frozen_string_literal: true

module NexusCcs
  # Help text for the place it is needed (CCS-101): a button beside a heading or label that shows a short note and a link
  # to the matching section of the Help page. A toggletip, not a hover tooltip: the note is real text in the page, linked
  # to its button by aria-controls, so it works with a keyboard, touch and a screen reader. Behaviour:
  # controllers/help_tip_controller.js. The wording is in config/locales/en.yml (nexus_ccs.help_tips); add a topic there.
  class HelpTipComponent < ViewComponent::Base
    def initialize(topic:)
      @topic = topic
      @tip = I18n.t!("nexus_ccs.help_tips.#{topic}")
    rescue I18n::MissingTranslationData
      raise KeyError, "no help tip for #{topic.inspect}"
    end

    def label = @tip[:label]
    def text = @tip[:text]
    def help_path = "/help##{@tip[:anchor]}"

    # Two tips of one topic on a page would clash, so the id carries the object's id
    def text_id = "help-tip-#{@topic.to_s.dasherize}-#{object_id}"
  end
end
