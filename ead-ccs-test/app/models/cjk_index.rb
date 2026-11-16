# frozen_string_literal: true

# Whether the Solr core the app talks to has the Chinese, Japanese and Korean fields (CCS-56: solr/conf/schema.xml, text_cjk and
# title_cjk, description_cjk...). A core made before that change does not have them, and a search that names them would fail, so the
# "Chinese, Japanese, Korean" search option and the CJK part of the Description search appear only once the core is known to have them.
#
# The answer is kept in memory for TTL seconds and is asked of Solr (its schema, a read) only on a results page (CatalogController),
# never while drawing another page, so a page that makes no Solr request still makes none. Until the first answer, and whenever Solr
# cannot be asked, the answer is "no": the site works as before.
module CjkIndex
  FIELD = "all_text_cjk"
  TTL = 600

  class << self
    # Is the CJK search offered? Never asks Solr.
    def available? = state.available

    # Asks Solr, at most once per TTL, whether the schema has the fields. Returns the answer.
    def refresh!
      return available? unless probe? && stale?

      @state = State.new(schema_has_field?, now)
      available?
    end

    # For tests: set the answer (nil: forget it) without asking Solr
    def force(value) = @state = value.nil? ? nil : State.new(value, now)
    def probe? = @probe.nil? ? !Rails.env.test? : @probe
    def probe=(value)
      @probe = value
    end

    private

    State = Struct.new(:available, :at)

    def state = @state || State.new(false, nil)
    def stale? = @state.nil? || now - @state.at > TTL
    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    def schema_has_field?
      response = Blacklight.default_index.connection.get("admin/luke", params: { show: "schema", wt: "json" })
      response.dig("schema", "fields")&.key?(FIELD) || false
    rescue StandardError => e
      Rails.logger.warn("CJK search check unavailable: #{e.class}")
      false
    end
  end
end
