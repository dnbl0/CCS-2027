# frozen_string_literal: true

# Colours of the records' images (docs/colour-and-clean-up.md). They read and write DAM_SOLR_URL only, never the shared core.
namespace :colour do
  desc "Work out the colours of every record's image in the DAM index (DAM_SOLR_URL) into record_colours. Resumes; FRESH=1 does " \
       "every record again; LIMIT=n stops after n images; COLOUR_RATE (default 4) image requests a second"
  task extract: :environment do
    logger = Logger.new($stdout)
    extractor = Colour::Extractor.new(solr: WritableCore.connect, fresh: ENV["FRESH"].present?, limit: ENV["LIMIT"].presence&.to_i, logger: logger)
    report = extractor.run
    puts report
    puts "Failures: tmp/colour_extract_failures.csv" if report.failed.positive?
  end

  desc "Write the colours (colour_ssim, colour_palette_ssm) into the DAM index (DAM_SOLR_URL): the records whose colours changed only"
  task write: :environment do
    puts "#{Colour::IndexWriter.new(solr: WritableCore.connect).write} records updated"
  end

  desc "Work out each record's closest records by colour (colour_neighbours), for the record page's Looks similar"
  task neighbours: :environment do
    puts "#{Colour::Neighbours.new.run} records have records that look similar"
  end
end
