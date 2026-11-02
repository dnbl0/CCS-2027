# frozen_string_literal: true

module NexusCcs
  # Choosing records to download the digital assets of, on the saved records page and a named list (CCS-167). A disclosure
  # ("Download digital assets") holding a form: a group of checkboxes, one per record that has assets, each saying whether its
  # files can be downloaded (from BulkDownload's own plan, so the page and the download agree), and a button that goes to the
  # review page (BulkDownloadsController). The checkboxes are in a form of their own, not in the result cards, which already
  # contain the Save forms. Works without JavaScript. The wording is in config/locales/en.yml (nexus_ccs.bulk_download).
  class BulkSelectionComponent < ViewComponent::Base
    Row = Struct.new(:document, :title, :status)

    def initialize(documents:, return_to:)
      @documents = documents.select { |document| assets?(document) }
      @return_to = return_to
    end

    attr_reader :return_to

    def render? = @documents.any?

    def rows
      @rows ||= begin
        viewing = Sensitivity::Choices.new(helpers.session)
        plan = BulkDownload.new(@documents, may_view_sensitive: ->(document) { viewing.viewing?(document.id) })
        @documents.map do |document|
          items = plan.items.select { |item| item.document.equal?(document) }
          skip = plan.skipped.find { |entry| entry.document.equal?(document) }
          status = items.any? ? t("nexus_ccs.bulk_download.status.downloadable", count: items.size) : t("nexus_ccs.bulk_download.status.#{skip&.reason || :no_assets}")
          Row.new(document, Array(document["title_tsim"]).first.presence || document.id, status)
        end
      end
    end

    def limits_hint
      t("nexus_ccs.bulk_download.limits", records: BulkDownload::MAX_RECORDS, files: BulkDownload::MAX_FILES,
        size: helpers.number_to_human_size(BulkDownload::MAX_BYTES))
    end

    private

    def assets?(document)
      Array(document["digital_asset_large_paths_ssim"]).any? || Array(document["digital_media_ssim"]).any?
    end
  end
end
