# frozen_string_literal: true

require "csv"

# One record's metadata as a CSV file (CCS-163, for records in the :open tier only: the controller asks AccessPolicy). The
# columns are what the record page shows, in its order: UoM ID, Title, the workbook's fields the record has a value for,
# the licence, and the persistent link. A header row of labels, then one row of values; a field with several values joins them with " | ".
# (Wide, not one row per field, so several records can later share one file.)
#
# The file starts with a UTF-8 byte order mark. Without it Excel opens a UTF-8 CSV as Windows-1252 and garbles the macrons,
# accents and other non-ASCII characters this collection is full of (Wurundjeri, Māori, "Hōkūle'a"); with it, Excel, Numbers
# and Sheets all read it as UTF-8, and tools that expect plain UTF-8 only see one extra invisible character in the first
# header. Every cell goes through CsvCell, so a value that starts = + - @ is not run as a formula.
class RecordCsv
  BOM = "﻿"
  SEPARATOR = " | "

  # show_fields: [[label, solr field]] in display order (CatalogController's show_fields)
  def initialize(document, show_fields:, persistent_link:)
    @document = document
    @show_fields = show_fields
    @persistent_link = persistent_link
  end

  def columns
    @columns ||= begin
      list = [ [ "UoM ID", uom_id ], [ "Title", Array(@document["title_tsim"]).first.to_s ] ]
      @show_fields.each do |label, field|
        values = Array(@document[field]).map(&:to_s).compact_blank
        list << [ label, values.join(SEPARATOR) ] if values.any?
      end
      licence = Array(@document["licence_type_ssim"]).map(&:to_s).compact_blank.join(SEPARATOR)
      list << [ "Licence", licence ] if licence.present? # shown in the page's Copyright card, not its details list
      list << [ "Persistent link", @persistent_link ]
    end
  end

  def to_csv
    BOM + CSV.generate(force_quotes: false) do |csv|
      csv << columns.map { |label, _| CsvCell.safe(label) }
      csv << columns.map { |_, value| CsvCell.safe(value) }
    end
  end

  # "ccs-emu-400329-metadata.csv": only the characters a file name can safely hold
  def filename = "ccs-#{@document.id.to_s.gsub(/[^A-Za-z0-9._-]/, "_")}-metadata.csv"

  private

  # The same UoM ID as the record page's details list
  def uom_id = CollectionIdentifier.uom_id(@document.id)
end
