# frozen_string_literal: true

# The Nexus DAM sync (docs/dam-sync.md). The token comes from ENV (DAM_API_TOKEN); the index written is DAM_SOLR_URL only.
namespace :dam do
  def dam_logger
    Logger.new($stdout).tap { |logger| logger.formatter = proc { |_severity, time, _name, message| "#{time.strftime('%H:%M:%S')} #{message}\n" } }
  end

  desc "Read the Nexus DAM into dam_assets and update the DAM index (DAM_SOLR_URL). FULL=1 reads every asset (resuming a " \
       "stopped full run; FRESH=1 starts again); otherwise only what changed since the last run"
  task sync: :environment do
    sync = Dam::Sync.new(logger: dam_logger)
    ENV["FULL"].present? ? sync.full(resume: ENV["FRESH"].blank?) : sync.incremental
  end

  desc "Rewrite the DAM index fields (DAM_SOLR_URL) from dam_assets, without reading the DAM: after a change to the rules " \
       "that decide them (AccessPolicy, Dam::SolrWriter). Only records whose fields change are sent"
  task write: :environment do
    updated = Dam::SolrWriter.from_env.write(DamAsset.distinct.pluck(:accession_number))
    puts "#{updated} records updated"
  end

  desc "Mark assets the DAM no longer has as deleted, and update their records in the DAM index"
  task reconcile: :environment do
    Dam::Sync.new(logger: dam_logger).reconcile
  end

  desc "Copy every record of the shared core (FROM, default SOLR_URL) into the DAM sync's own core (TO, default DAM_SOLR_URL)"
  task copy_index: :environment do
    from = ENV["FROM"].presence || ENV.fetch("SOLR_URL")
    to = ENV["TO"].presence || ENV.fetch("DAM_SOLR_URL")
    puts "#{Dam::IndexCopy.new(from: from, to: to, logger: dam_logger).run} records copied from #{from} to #{to}"
  end

  desc "Report the DAM assets whose accession number matches no record in the DAM index; writes OUT (default tmp/dam_unmatched.csv)"
  task report: :environment do
    out = ENV.fetch("OUT", Rails.root.join("tmp/dam_unmatched.csv").to_s)
    report = Dam::Report.new(solr: RSolr.connect(url: ENV.fetch("DAM_SOLR_URL")))
    report.write_unmatched(out)
    puts report.summary
    puts "Unmatched assets: #{out}"
  end
end
