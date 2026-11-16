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
end
