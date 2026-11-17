# frozen_string_literal: true

# Where the records were made (docs/time-and-place.md). geo:geocode reads SOLR_URL only and asks OpenStreetMap Nominatim, one place a
# second; geo:write writes DAM_SOLR_URL only. Run on the owner's machine, never by the site.
namespace :geo do
  def geo_logger
    Logger.new($stdout).tap { |logger| logger.formatter = proc { |_severity, time, _name, message| "#{time.strftime('%H:%M:%S')} #{message}\n" } }
  end

  desc "Look up the production places (from SOLR_URL, read only) not yet in place_geocodes with OpenStreetMap Nominatim, one a " \
       "second. Resumable; DRY_RUN=1 counts what would be looked up; LIMIT=n stops after n lookups"
  task geocode: :environment do
    solr = RSolr.connect(url: ENV.fetch("SOLR_URL"))
    limit = ENV["LIMIT"].presence&.to_i
    report = Geo::Geocoder.new(solr: solr, logger: geo_logger, dry_run: ENV["DRY_RUN"].present?, limit: limit).run
    puts report.to_s
  end

  desc "Write the places' coordinates, countries, states and the Place filter (place_hierarchy_ssim) into the DAM index " \
       "(DAM_SOLR_URL only), for the records whose place fields changed"
  task write: :environment do
    puts "#{Geo::SolrWriter.from_env.write} records updated"
  end
end
