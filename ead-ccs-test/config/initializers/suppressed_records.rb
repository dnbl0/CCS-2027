# Records taken out of the public site (CCS-112; app/models/suppressed_record.rb, docs/remove-a-record.md): kept out of every Solr
# answer at the client, and a page that names one is a 410 Gone, not a 404.
Rails.application.config.to_prepare do
  RSolr::Client.prepend(SuppressedSolrFilter) unless RSolr::Client < SuppressedSolrFilter
end

ActionDispatch::ExceptionWrapper.rescue_responses["SuppressedRecord::Removed"] = :gone
