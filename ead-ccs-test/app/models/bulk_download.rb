# frozen_string_literal: true

require "csv"

# The digital assets of several selected records, as one zip file (CCS-167): which files go in, which records are left out and
# why, whether the whole is within the limits, and the zip itself. The visitor selects records on the saved records page or one of
# their lists (BulkDownloadsController); nothing is zipped until they have seen this plan.
#
# What goes in follows AccessPolicy: only records in the :open tier (download? is true). A :view_only record is skipped ("not
# downloadable") and a :request one ("withheld"); a sensitive record is skipped unless the visitor has chosen to view it
# (Sensitivity, may_view_sensitive). Only files this server holds under public/digital-assets are zipped: a file is found
# from its path in the index, which is resolved, then checked to lie inside that folder (no .., no symlink out of it).
#
# Limits (placeholders, for the University to set): MAX_RECORDS records chosen, MAX_FILES files and MAX_BYTES in the zip. A
# selection over a limit is refused whole, with the numbers, rather than cut short, so the visitor decides what to drop.
# The zip has each record's files in a folder named for the record, and manifest.csv, the "essential information" for
# each file (record, title, licence, rights, credit line, persistent link).
class BulkDownload
  MAX_RECORDS = 25
  MAX_FILES = 100
  MAX_BYTES = 200.megabytes
  ASSET_ROOT = Rails.root.join("public/digital-assets")
  MANIFEST = "manifest.csv"

  Item = Struct.new(:document, :zip_name, :path, :size, keyword_init: true)
  # reason: :withheld, :not_downloadable, :sensitive, :no_assets, :file_missing (name: the file), :not_found (no document)
  Skip = Struct.new(:document, :reason, :name, keyword_init: true)

  attr_reader :items, :skipped

  # documents: SolrDocuments; may_view_sensitive: ->(document) { true if the visitor has chosen to view it }
  def initialize(documents, may_view_sensitive: ->(_document) { false }, asset_root: ASSET_ROOT)
    @root = File.realpath(asset_root)
    @may_view_sensitive = may_view_sensitive
    @items = []
    @skipped = []
    @zip_names = {}
    documents.each { |document| plan(document) }
  end

  def total_bytes = items.sum(&:size)
  def records = items.map(&:document).uniq
  def files = items.size

  # nil when the download is within the limits, else why not: :too_many_files or :too_large (records are limited by the controller)
  def limit_problem
    return :too_many_files if files > MAX_FILES

    :too_large if total_bytes > MAX_BYTES
  end

  def downloadable? = items.any? && limit_problem.nil?

  # Writes the zip to io (a binary IO). persistent_link: ->(document) { url }
  def write_zip(io, persistent_link:)
    raise ArgumentError, "over the limits or nothing to download" unless downloadable?

    ZipWriter.write(io) do |zip|
      zip.add_data(MANIFEST, manifest(persistent_link))
      items.each { |item| zip.add_file(item.zip_name, item.path) }
    end
  end

  # "ccs-assets-20261102.zip"
  def self.filename(time = Time.current) = "ccs-assets-#{time.strftime('%Y%m%d')}.zip"

  # A folder or file name that holds only characters that are safe on every system
  def self.safe_part(text, fallback)
    cleaned = text.to_s.gsub(/[^A-Za-z0-9._-]/, "_").gsub(/\A\.+/, "_")
    cleaned.presence || fallback
  end

  private

  def plan(document)
    return skip(nil, :not_found) if document.nil?

    case AccessPolicy.tier(document)
    when :request then return skip(document, :withheld)
    when :view_only then return skip(document, :not_downloadable)
    end
    return skip(document, :sensitive) if Sensitivity.sensitive?(document) && !@may_view_sensitive.call(document)

    urls = asset_urls(document)
    return skip(document, :no_assets) if urls.empty?

    urls.each { |url| add_file(document, url) }
  end

  def add_file(document, url)
    path = local_path(url)
    return skip(document, :file_missing, File.basename(url.to_s.split("?").first.to_s)) unless path

    folder = self.class.safe_part(document.id, "record")
    name = self.class.safe_part(File.basename(path), "file")
    items << Item.new(document: document, zip_name: unique_name("#{folder}/#{name}"), path: path, size: File.size(path))
  end

  # The same file name twice in a record gets -2, -3...: "a.jpg", "a-2.jpg"
  def unique_name(name)
    candidate = name
    count = 1
    while @zip_names[candidate.downcase]
      count += 1
      candidate = name.sub(/(\.[^.\/]*)?\z/) { "-#{count}#{Regexp.last_match(1)}" }
    end
    @zip_names[candidate.downcase] = true
    candidate
  end

  def skip(document, reason, name = nil) = skipped << Skip.new(document: document, reason: reason, name: name)

  # Large images, then the audio, video and PDF files, as the record page shows them
  def asset_urls(document)
    media = Array(document["digital_media_ssim"]).map { |entry| Collections::DigitalMedia.parse(entry)[:url] }
    (Array(document["digital_asset_large_paths_ssim"]) + media).map(&:to_s).compact_blank.uniq
  end

  # The file on this server for a path such as /digital-assets/large/a.jpg, or nil: not under /digital-assets/, not a real
  # file, or (after resolving .. and symlinks) not inside the asset folder
  def local_path(url)
    prefix = "/digital-assets/"
    return nil unless url.start_with?(prefix)

    relative = URI::DEFAULT_PARSER.unescape(url.delete_prefix(prefix).split(/[?#]/).first.to_s)
    return nil if relative.empty? || relative.include?("\0")

    real = File.realpath(File.join(@root, relative))
    real if real.start_with?("#{@root}/") && File.file?(real)
  rescue SystemCallError, ArgumentError
    nil
  end

  def manifest(persistent_link)
    rows = items.map do |item|
      document = item.document
      [ document.id, Array(document["title_tsim"]).first, item.zip_name, Array(document["licence_type_ssim"]).join(" | "),
        Array(document["rights_ssim"]).first, Array(document["credit_line_tsim"]).first, persistent_link.call(document) ]
    end
    header = [ "Record ID", "Title", "File in this zip", "Licence", "Copyright", "Credit line", "Persistent link" ]
    "﻿" + CSV.generate do |csv|
      csv << header
      rows.each { |row| csv << row.map { |cell| CsvCell.safe(cell) } }
    end
  end
end
