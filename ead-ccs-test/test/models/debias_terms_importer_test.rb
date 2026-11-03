require "test_helper"
require "rake"
require_relative "../support/debias_helper"

class DebiasTermsImporterTest < ActiveSupport::TestCase
  HEADER = "term,match,case,languages,fields,explanation,alternative,severity,source,reviewed_on,enabled\n".freeze

  def import(csv) = DebiasTerms::Importer.new(csv).call

  test "a valid sheet becomes entries with the schema's fields" do
    result = import(<<~CSV)
      #{HEADER}Blorp,word,insensitive,en; fr,title; description,Made-up reason.,Zank,caution,Test team,2026-11-03,yes
      zank wib,phrase,,,,Another reason.,,,Test team,2026-11-03,
    CSV

    assert_predicate result, :ok?, result.errors.inspect
    blorp, phrase = result.entries
    assert_equal [ "blorp", "Blorp", %w[en fr], %w[title description], "caution", true, "Zank" ], [ blorp.id, blorp.term, blorp.languages, blorp.fields, blorp.severity, blorp.enabled, blorp.alternative ]
    assert_equal [ "zank-wib", "phrase", %w[en], %w[all], "note", false, nil ], [ phrase.id, phrase.match, phrase.languages, phrase.fields, phrase.severity, phrase.enabled, phrase.alternative ]
    assert_match(/1 of 2 entries are not enabled/, result.warnings.join)
  end

  test "headings are matched loosely and extra columns are warned about" do
    result = import("Term,Match Mode,Reviewed,Explanation,Owner,Notes\nblorp,word,2026-11-03,Why.,Test team,hello\n")

    assert_predicate result, :ok?, result.errors.inspect
    assert_match(/notes column is not used/, result.warnings.join)
  end

  test "missing and repeated columns are reported" do
    result = import("term,explanation\nblorp,Why.\n")
    assert_includes result.errors, "the sheet has no source column"
    assert_includes result.errors, "the sheet has no reviewed_on column"

    assert_includes import("term,term,explanation,source,reviewed_on\na,b,c,d,2026-01-01\n").errors, "the term column appears 2 times"
  end

  test "every bad row is reported with its row number" do
    result = import(<<~CSV)
      #{HEADER}bl*rp,word,,,,Why.,,,Test,2026-11-03,yes
      two words,word,,,,Why.,,,Test,2026-11-03,yes
      one,phrase,,,,Why.,,,Test,2026-11-03,yes
      ab,prefix,,,,Why.,,,Test,2026-11-03,yes
      fine,word,,xx_yy,nowhere,,,loud,,not a date,maybe
      (a+)+$,word,,,,Why.,,,Test,2026-11-03,yes
    CSV

    errors = result.errors.join("\n")
    assert_match(/row 2: term "bl\*rp" has pattern characters/, errors)
    assert_match(/row 3: a word entry is one word/, errors)
    assert_match(/row 4: a phrase entry needs two or more words/, errors)
    assert_match(/row 5: a prefix must be at least 3/, errors)
    assert_match(/row 6: language code "xx_yy"/, errors)
    assert_match(/row 6: field "nowhere"/, errors)
    assert_match(/row 6: explanation is required/, errors)
    assert_match(/row 6: severity "loud"/, errors)
    assert_match(/row 6: source is required/, errors)
    assert_match(/row 6: reviewed_on must be a date/, errors)
    assert_match(/row 6: enabled "maybe"/, errors)
    assert_match(/row 7: term "\(a\+\)\+\$" has pattern characters/, errors)
    assert_empty result.entries.select { |entry| entry.term.include?("*") }
  end

  test "duplicates are reported, ignoring case unless the entry is case sensitive" do
    result = import(<<~CSV)
      #{HEADER}Blorp,word,,,,Why.,,,Test,2026-11-03,yes
      blorp,word,,,,Why.,,,Test,2026-11-03,yes
      Zank,word,sensitive,,,Why.,,,Test,2026-11-03,yes
      zank,word,sensitive,,,Why.,,,Test,2026-11-03,yes
    CSV

    assert_equal [ "row 3: duplicate of row 2 (same id)", "row 3: duplicate of row 2 (same term, match and case)" ], result.errors.first(2)
    assert_equal 1, result.errors.count { |error| error.include?("same term, match and case") }
    assert_includes result.errors, "row 5: duplicate of row 4 (same id)", "different case, same generated id: the sheet needs an id column to tell them apart"
  end

  test "empty, malformed and non UTF-8 files are refused with a reason" do
    assert_equal [ "the file is empty" ], import("  \n").errors
    assert_match(/not valid CSV/, import("term,explanation\n\"unclosed,x\n").errors.first)
    assert_match(/not valid UTF-8/, import("term\n\xFF\n".b).errors.first)
  end

  test "a byte order mark from Excel and blank rows are tolerated" do
    result = import("﻿#{HEADER}\nblorp,word,,,,Why.,,,Test,2026-11-03,yes\n,,,,,,,,,,\n")

    assert_predicate result, :ok?, result.errors.inspect
    assert_equal 1, result.entries.size
  end

  test "the YAML written loads back into the same entries" do
    result = import("#{HEADER}Blorp,word,,en,title,Why.,Zank,caution,Test team,2026-11-03,yes\n")
    Dir.mktmpdir do |dir|
      path = File.join(dir, "terms.yml")
      File.write(path, DebiasTerms::Importer.yaml(result.entries))

      assert_equal result.entries, DebiasTerms.send(:load_entries, path)
      assert_match(/\A# De-bias notices/, File.read(path))
    end
  end

  test "an entry in another script gets an id" do
    entry, errors = DebiasTerms::Entry.parse(debias_hash("ξένος"))
    assert_empty errors
    assert_match(/\Aterm-[0-9a-f]{10}\z/, entry.id)
  end

  def debias_hash(term) = { "term" => term, "explanation" => "x", "source" => "s", "reviewed_on" => "2026-11-03", "enabled" => true }
end

class DebiasRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("debias:import")
    Rake::Task["debias:import"].reenable
    @dir = Dir.mktmpdir
  end

  teardown do
    FileUtils.remove_entry(@dir)
    ENV.delete("CSV")
    ENV.delete("OUT")
  end

  def run_import(csv)
    path = File.join(@dir, "in.csv")
    File.write(path, csv)
    ENV["CSV"] = path
    ENV["OUT"] = File.join(@dir, "out.yml")
    capture_io { Rake::Task["debias:import"].invoke }
  end

  test "debias:import writes the list when the sheet is valid" do
    out, = run_import("#{DebiasTermsImporterTest::HEADER}Blorp,word,,,,Why.,,,Test,2026-11-03,yes\n")

    assert_match(/Wrote 1 entries \(1 enabled\)/, out)
    assert_equal [ "Blorp" ], DebiasTerms.send(:load_entries, File.join(@dir, "out.yml")).map(&:term)
  end

  test "debias:import writes nothing and stops when the sheet has a problem" do
    error = assert_raises(SystemExit) { run_import("#{DebiasTermsImporterTest::HEADER}bl*rp,word,,,,Why.,,,Test,2026-11-03,yes\n") }

    assert_not error.success?
    assert_not File.exist?(File.join(@dir, "out.yml"))
  end
end

class DebiasReportTest < ActiveSupport::TestCase
  include DebiasHelper

  test "the report counts records and occurrences of each enabled term, and lists terms found nowhere with zero" do
    records = [ { "id" => "a", "title_tsim" => [ "Blorp and blorp" ] }, { "id" => "b", "description_tsim" => [ "a blorp" ], "restrictions_tsi" => [ "zank" ] },
                { "id" => "c", "title_tsim" => [ "nothing" ] } ]

    with_debias_terms("blorp", "zank", debias_entry("never", enabled: true), debias_entry("off", enabled: false)) do
      scanned = nil
      lines = DebiasTerms::Report.new(records: -> { records }).call(scanned: ->(count) { scanned = count })

      assert_equal 3, scanned
      assert_equal [ [ "blorp", 2, 3, %w[a b] ], [ "never", 0, 0, [] ], [ "zank", 0, 0, [] ] ], lines.map { |l| [ l.entry.term, l.records, l.occurrences, l.examples ] }
    end
  end
end
