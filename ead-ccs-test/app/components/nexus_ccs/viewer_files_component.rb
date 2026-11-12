# frozen_string_literal: true

module NexusCcs
  # The video, audio and PDF files of a record in the viewer layout (?layout=viewer): their own band right after the headline, each file
  # in a big rounded card (players full width; a PDF as a card with its open link). They are not in the hero, which holds only the
  # picture, so nothing can scroll inside it. What is shown follows AccessPolicy exactly as DigitalAssetsComponent does (`media`: none for a
  # withheld record or one waiting for the visitor's choice, a PDF only for an open record, the players' download button only when open).
  class ViewerFilesComponent < DigitalAssetsComponent
    def render? = media.any?

    # PLACEHOLDER WORDING, NOT YET APPROVED (record_page.viewer.files_*): by what the files are
    def heading
      kinds = media.map { |item| item[:kind].to_s }.uniq
      key = if kinds == %w[pdf] then :files_read
      elsif kinds.include?("pdf") then :files_all
      else :files_watch
      end
      t("nexus_ccs.record_page.viewer.#{key}")
    end
  end
end
