# frozen_string_literal: true

# Whether the Solr core has the PDF text field (CCS-36: pdf_text_tim in solr/conf/schema.xml). A core made before that does not, and
# a search that names it would fail, so the "Full text" search is offered only once the core is known to have it. Asked of Solr's
# schema on a results page only (CatalogController), at most every TTL seconds; "cannot ask" is "not there".
module PdfTextIndex
  FIELD = "pdf_text_tim"
  TTL = 600
  State = Struct.new(:available, :at)

  class << self
    def available? = (@state || State.new(false, nil)).available

    def refresh!
      return available? unless probe? && (@state.nil? || now - @state.at > TTL)

      @state = State.new(schema_has_field?, now)
      available?
    end

    # For tests: set the answer (nil: forget it) without asking Solr
    def force(value) = @state = value.nil? ? nil : State.new(value, now)
    def probe? = @probe.nil? ? !Rails.env.test? : @probe

    attr_writer :probe

    private

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    def schema_has_field?
      response = Blacklight.default_index.connection.get("admin/luke", params: { show: "schema", wt: "json" })
      response.dig("schema", "fields")&.key?(FIELD) || false
    rescue StandardError => e
      Discovery.log_failure("PDF text search check", e)
      false
    end
  end
end
