require "csv"
require "etc"

# Taking a record out of the public site, and putting it back (CCS-112; docs/remove-a-record.md). There is no sign-in, so staff
# do it here, on the server. SUPPRESSED_BY=<name> says who (free text; default the server's user name).
namespace :records do
  # rake splits its arguments at commas, so a reason with commas arrives in pieces: put them back, and drop quotes around it
  def reason_from(args) = ([ args[:reason] ] + args.extras).compact.join(",").strip.delete_prefix('"').delete_suffix('"').strip

  def record_id_from(args)
    id = args[:id].to_s.strip
    abort "Give the record's id: bin/rails 'records:suppress[ID,reason]'" if id.empty?
    abort "#{id.inspect} is not a record id (letters, digits and . _ : - only, at most 200 characters)." unless SuppressedRecord.valid_id?(id)

    id
  end

  desc 'Take a record out of the site: bin/rails "records:suppress[ID,Why it is removed]" (again with a new reason changes the reason)'
  task :suppress, [ :id, :reason ] => :environment do |_task, args|
    id = record_id_from(args)
    reason = reason_from(args)
    abort "Give a reason (it is kept for the record of the removal): bin/rails 'records:suppress[#{id},reason]'" if reason.empty?

    existed = SuppressedRecord.suppressed?(id) || SuppressedRecord.exists?(record_id: id)
    SuppressedRecord.suppress!(id, reason: reason, by: ENV.fetch("SUPPRESSED_BY") { Etc.getlogin })
    puts existed ? "#{id} was already removed; the reason is updated." : "#{id} is removed from the site."
    puts "Running servers stop showing it within #{ENV.fetch('SUPPRESSED_RECORDS_CACHE_SECONDS', 30)} seconds. Its address, embeds and manifest answer 410 Gone."
  end

  desc 'Put a removed record back: bin/rails "records:unsuppress[ID]"'
  task :unsuppress, [ :id ] => :environment do |_task, args|
    id = record_id_from(args)
    puts SuppressedRecord.unsuppress!(id) ? "#{id} is back on the site." : "#{id} was not removed; nothing to do."
  end

  desc "List the records taken out of the site, as CSV (id, when, who, reason)"
  task suppressed: :environment do
    puts CSV.generate_line(%w[record_id suppressed_at suppressed_by reason])
    SuppressedRecord.order(:suppressed_at).find_each do |record|
      puts CSV.generate_line([ record.record_id, record.suppressed_at.iso8601, record.suppressed_by, record.reason ].map { |value| CsvCell.safe(value) })
    end
  end

  # --- Metadata from a CSV (CCS-31; docs/csv-upload.md). Neither task posts to Solr unless INDEX=1 and SOLR_URL is set to a writable core. ---

  # CCS-31 criterion 6: take an uploaded set out of the site, in full (the CSV that was uploaded) or in part (a CSV of only the ids
  # to remove). Each row's record (csv-<id>, as records:csv_to_documents indexes it) is removed as records:suppress removes one
  # (CCS-112), with the same reason, so records:unsuppress puts any of them back.
  desc 'Take the records of an uploaded CSV out of the site: bin/rails "records:remove_csv[file.csv,Why they are removed]"'
  task :remove_csv, [ :path, :reason ] => :environment do |_task, args|
    path = args[:path].to_s
    abort "Give the CSV file and a reason: bin/rails 'records:remove_csv[file.csv,reason]'" unless File.file?(path)
    reason = reason_from(args)
    abort "Give a reason (it is kept for the record of the removal): bin/rails 'records:remove_csv[#{path},reason]'" if reason.empty?

    table = CSV.parse(Collections::CsvSource.read_text(path), headers: true)
    column = table.headers.compact.find { |header| Collections::CsvSource.normalise(header) == "id" }
    abort "The file has no id column." unless column

    source = Collections::CsvSource.new(path)
    ids = table.filter_map { |row| row[column].to_s.strip.presence }.uniq.map { |id| source.send(:document_id, id) } # as indexed
    bad = ids.reject { |id| SuppressedRecord.valid_id?(id) }
    abort "Not record ids (nothing removed): #{bad.join(', ')}" if bad.any?

    by = ENV.fetch("SUPPRESSED_BY") { Etc.getlogin }
    ids.each { |id| SuppressedRecord.suppress!(id, reason: reason, by: by) }
    puts "#{ids.size} #{ids.size == 1 ? 'record' : 'records'} removed from the site: #{ids.join(', ')}"
    puts "Running servers stop showing them within #{ENV.fetch('SUPPRESSED_RECORDS_CACHE_SECONDS', 30)} seconds."
  end

  def csv_path_from(args)
    path = args[:path].to_s
    abort "Give the CSV file: bin/rails 'records:validate_csv[path/to/file.csv]'" if path.empty?
    abort "#{path} is not a file." unless File.file?(path)

    path
  end

  desc "Check a metadata CSV row by row and print the problems and a summary (nothing is indexed): bin/rails 'records:validate_csv[file.csv]'"
  task :validate_csv, [ :path ] => :environment do |_task, args|
    report = Collections::CsvSource.new(csv_path_from(args)).check
    puts CSV.generate_line(%w[line id problem])
    report.problems.each { |problem| puts CSV.generate_line([ problem.line, problem.id, problem.message ].map { |value| CsvCell.safe(value) }) }
    warn "Missing required columns: #{report.missing_columns.join(', ')}" if report.missing_columns.any?
    warn "Unknown columns (ignored, not indexed): #{report.unknown_columns.join(', ')}" if report.unknown_columns.any?
    warn "#{report.rows} rows, #{report.problems.map(&:line).uniq.size} with problems, #{report.problems.size} problems. #{report.ok? ? 'Ready to convert.' : 'Fix these first.'}"
    exit(1) unless report.ok?
  end

  desc "Print the Solr JSON for a metadata CSV (OUT=file.json to write a file; INDEX=1 SOLR_URL=<writable core> to index it): bin/rails 'records:csv_to_documents[file.csv]'"
  task :csv_to_documents, [ :path ] => :environment do |_task, args|
    source = Collections::CsvSource.new(csv_path_from(args))
    report = source.check(documents: true)
    abort "Not converted: #{report.problems.size} problems, #{report.unknown_columns.size} unknown and #{report.missing_columns.size} missing columns. Run records:validate_csv first." unless report.ok?

    json = JSON.pretty_generate(report.documents)
    ENV["OUT"].present? ? File.write(ENV["OUT"], json) : puts(json)
    warn "#{report.documents.size} documents#{" written to #{ENV['OUT']}" if ENV['OUT'].present?}."
    next unless ENV["INDEX"] == "1"

    url = ENV["SOLR_URL"].to_s
    abort "INDEX=1 needs SOLR_URL set to the core to write to." if url.empty?
    abort "Refusing to index into #{url}: port 8984 is the shared, read-only Solr." if URI(url).port == 8984
    Collections::Indexer.new(solr_url: url).index(source)
  end
end
