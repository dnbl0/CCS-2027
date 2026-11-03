namespace :debias do
  desc "Check the collections team's spreadsheet (CSV=path) and write the term list (OUT=path, default config/debias_terms.yml)"
  task import: :environment do
    path = ENV["CSV"].presence or abort "usage: bin/rails debias:import CSV=path/to/terms.csv  (OUT=path to write somewhere else)"
    result = DebiasTerms::Importer.read(path).call
    result.warnings.each { |warning| warn "warning: #{warning}" }
    unless result.ok?
      result.errors.each { |error| warn "error: #{error}" }
      abort "#{result.errors.size} problem(s) found; nothing was written. Fix the spreadsheet and run it again."
    end

    out = ENV["OUT"].presence || DebiasTerms::PATH.to_s
    File.write(out, DebiasTerms::Importer.yaml(result.entries))
    puts "Wrote #{result.entries.size} entries (#{result.entries.count(&:enabled)} enabled) to #{out}."
  end

  desc "List which enabled de-bias terms occur in the index and how often (reads Solr, changes nothing)"
  task report: :environment do
    if DebiasTerms.enabled.empty?
      puts "No terms are enabled in #{DebiasTerms::PATH}, so there is nothing to report."
      next
    end

    lines = DebiasTerms::Report.new.call(scanned: ->(count) { puts "Scanned #{count} records." })
    lines.each do |line|
      puts format("%-30s %-8s %6d records %6d times  %s", line.entry.term, line.entry.severity, line.records, line.occurrences,
                  line.examples.join(" "))
    end
    puts "#{lines.count { |line| line.records.zero? }} enabled term(s) occur in no record."
  end
end
