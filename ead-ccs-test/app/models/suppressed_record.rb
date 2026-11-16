# frozen_string_literal: true

# A record taken out of the public site (CCS-112: "suppress/remove a record when required ... rapid removal"). Staff add and lift
# a suppression with rake tasks (records:suppress, records:unsuppress, records:suppressed; docs/remove-a-record.md): there is no
# sign-in, so no admin page.
#
# One list, applied in one place. SuppressedSolrFilter (config/initializers/suppressed_records.rb) adds `-{!terms f=id}...` to every
# search Solr is asked for, whichever code asks, so a suppressed record is absent from results, counts, facets, the sitemap, Similar
# records, Related objects, Featured, saved lists and the rest. The record's own address, embed, oEmbed, manifest, export and the
# other pages that name a record answer 410 Gone (Removed, below). The index itself is not changed: lifting the suppression
# brings the record back.
#
# The list of ids is read from the database and kept in memory for CACHE_SECONDS (SUPPRESSED_RECORDS_CACHE_SECONDS), and at once
# in the process that changed it, so a suppression reaches every running server within that time. Cached pages that hold record
# counts include `version` in their cache key, so they are rebuilt without the record rather than served for a day.
class SuppressedRecord < ApplicationRecord
  # Raised where a page names a suppressed record. ActionDispatch maps it to 410 (config/initializers/suppressed_records.rb),
  # and ErrorsController draws the page.
  class Removed < StandardError
    def initialize(message = "This record has been removed") = super
  end

  # What a record id may be: letters, digits and . _ : - (never a comma or a space, so the filter below needs no escaping)
  ID_FORMAT = /\A[A-Za-z0-9][A-Za-z0-9._:-]{0,199}\z/

  validates :record_id, presence: true, format: { with: ID_FORMAT, allow_blank: true }, uniqueness: true
  validates :reason, presence: true, length: { maximum: 2000 }
  validates :suppressed_by, length: { maximum: 200 }

  after_commit { SuppressedRecord.forget! }

  Snapshot = Struct.new(:ids, :read_at)

  class << self
    def valid_id?(id) = id.to_s.match?(ID_FORMAT)

    def suppressed?(id) = ids.include?(id.to_s)

    # Raises Removed for a suppressed record. For any code that is about to name a record.
    def guard!(id)
      raise Removed if suppressed?(id)
    end

    # The suppressed ids (a frozen Set). If the database cannot be read, the last list read stands (an empty one if there never was one).
    def ids
      snapshot = @snapshot
      return snapshot.ids if snapshot && Process.clock_gettime(Process::CLOCK_MONOTONIC) - snapshot.read_at < cache_seconds

      @snapshot = Snapshot.new(load_ids(snapshot), Process.clock_gettime(Process::CLOCK_MONOTONIC))
      @snapshot.ids
    end

    # Forget what was read: the next question reads the database
    def forget!
      @snapshot = nil
    end

    # Changes with the list: part of the cache key of anything cached that counts or lists records
    def version
      list = ids
      list.empty? ? "none" : Digest::SHA1.hexdigest(list.sort.join(","))[0, 10]
    end

    # `key` unchanged while nothing is suppressed (so nothing cached is lost), and a key of its own for each list
    def cache_key(key) = ids.empty? ? key : "#{key}/suppressed-#{version}"

    # The Solr filter query that leaves them out, or nil when there are none. A terms query has no clause limit.
    def solr_filter
      list = ids
      list.empty? ? nil : "-{!terms f=id}#{list.sort.join(',')}"
    end

    # Suppress a record. Idempotent: suppressing again changes the reason (and who), never the date. Returns the SuppressedRecord.
    def suppress!(id, reason:, by: nil)
      record = find_or_initialize_by(record_id: id.to_s)
      record.suppressed_at ||= Time.current
      record.reason = reason.to_s.strip
      record.suppressed_by = by.to_s.strip.presence || record.suppressed_by
      record.save!
      record
    end

    # Lift it. Returns true if there was a suppression to lift.
    def unsuppress!(id)
      record = find_by(record_id: id.to_s)
      record&.destroy!
      record.present?
    end

    private

    def cache_seconds = Integer(ENV.fetch("SUPPRESSED_RECORDS_CACHE_SECONDS", 30), exception: false) || 30

    def load_ids(previous)
      Set.new(order(:record_id).pluck(:record_id)).freeze
    rescue ActiveRecord::ActiveRecordError, PG::Error => e
      Rails.logger.warn("Suppressed records unavailable: #{e.class}")
      previous&.ids || Set.new.freeze
    end
  end
end
