# frozen_string_literal: true

module NexusCcs
  # The "Select" checkbox on a result card (CCS-40). Its label starts with the visible word, so the accessible name contains
  # it ("Select: Cat skull"). The box belongs to the selection form above the results (SelectionBarComponent::FORM_ID, by its
  # `form` attribute), because the card already holds other forms.
  class SelectBoxComponent < ViewComponent::Base
    def initialize(document_id:, title:)
      @document_id = document_id.to_s
      @title = title
    end

    attr_reader :title, :document_id

    def input_id = "select-#{document_id.parameterize}"

    def selected? = Selection.new(helpers.session).include?(document_id)
  end
end
