namespace :collections do
  # Override with EMU_CSV / VERNON_CSV / HARVESTED_CSV. Any may be omitted to load just the others.
  def configured_sources
    {
      Collections::EmuSource   => ENV.fetch("EMU_CSV", Rails.root.join("data", "emu.csv").to_s),
      Collections::VernonSource => ENV.fetch("VERNON_CSV", Rails.root.join("data", "vernon.csv").to_s),
      Collections::HarvestedSource => harvested_csv
    }.filter_map do |klass, path|
      if File.exist?(path)
        klass.new(path)
      else
        warn "skipping #{klass.name.demodulize}: #{path} not found"
        nil
      end
    end
  end

  desc "Index the M&C collection exports into Solr (idempotent; FORCE=1 to reindex)"
  task index: :environment do
    indexer = Collections::Indexer.new
    sources = configured_sources
    abort "no source CSVs found -- set EMU_CSV and/or VERNON_CSV" if sources.empty?

    existing = indexer.document_count
    if existing.positive? && ENV["FORCE"].blank?
      puts "Core already holds #{existing} documents; set FORCE=1 to reindex. Skipping."
      next
    end

    result = indexer.index(sources)
    puts "Indexed #{result[:indexed]} documents (#{result[:duplicate_ids]} duplicate ids)."
  end

  def harvested_csv = ENV.fetch("HARVESTED_CSV", Rails.root.join("data", "harvested.csv").to_s)

  # Adds (or replaces) only the harvested records, so a core that already holds the EMu and Vernon records keeps them as they are.
  desc "Index data/harvested.csv into Solr alongside what the core already holds"
  task index_harvested: :environment do
    result = Collections::Indexer.new.index([ Collections::HarvestedSource.new(harvested_csv) ])
    puts "Indexed #{result[:indexed]} harvested documents (#{result[:duplicate_ids]} duplicate ids)."
  end

  desc "Print the first mapped document from each source without touching Solr"
  task preview: :environment do
    configured_sources.each do |source|
      puts "\n=== #{source.name}: #{source.path} ==="
      document = source.each_document.first
      abort "no rows produced a document" if document.nil?

      document.sort.each { |field, value| puts format("  %-34s %s", field, Array(value).join(" | ")) }
    end
  end

  desc "Delete every document from the Solr core"
  task clear: :environment do
    Collections::Indexer.new.clear
    puts "Core emptied."
  end
end
