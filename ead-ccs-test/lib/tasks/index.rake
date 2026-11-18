# frozen_string_literal: true

namespace :index do
  desc "Write the cleaned-up Materials / Medium and Nationality terms (material_term_ssim, nationality_term_ssim) into the DAM " \
       "index (DAM_SOLR_URL), for the records whose terms changed only; lists unrecognised nationalities in tmp/nationality_unparsed.csv"
  task normalise: :environment do
    puts Normalise::IndexWriter.new(solr: WritableCore.connect).write
    puts "Nationality values with no match: tmp/nationality_unparsed.csv"
    puts "Restart the site so the Materials / Medium and Nationality filters read the new terms."
  end
end
