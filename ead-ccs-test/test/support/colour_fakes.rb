# frozen_string_literal: true

# A stand-in for the writable Solr core (DAM_SOLR_URL) for the colour and clean-up tasks: it answers cursor-paged selects from the
# docs it holds (q and fq are not evaluated: the test gives the records the query would find) and keeps what is sent to it.
class FakeWritableCore
  attr_reader :added, :commits, :requests

  def initialize(docs)
    @docs = docs.map { |doc| doc.transform_keys(&:to_s) }
    @added = []
    @commits = 0
    @requests = []
  end

  def get(_path, params:)
    @requests << params
    start = params[:cursorMark] == "*" ? 0 : params[:cursorMark].to_i
    page = @docs.drop(start).first(params[:rows])
    { "response" => { "docs" => page, "numFound" => @docs.size }, "nextCursorMark" => page.empty? ? params[:cursorMark] : (start + page.size).to_s }
  end

  def add(docs) = @added.concat(docs)
  def commit = @commits += 1
end

module ColourFixtures
  DIR = Rails.root.join("test/fixtures/files/colour")

  def colour_fixture(name) = DIR.join(name).binread
end
