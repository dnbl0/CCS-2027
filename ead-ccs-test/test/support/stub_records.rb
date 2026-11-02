# frozen_string_literal: true

# Records for a controller test without Solr (the "rails" CI job has none): the controllers that find records through RecordLookup
# are given these documents instead. The methods are put back in an ensure, so a test that fails leaves nothing behind.
module StubRecords
  OPEN_LARGE = %w[/digital-assets/large/85827df9ab6c38d57468e763906aff80.jpg /digital-assets/large/uac_1982_0022_2_pf.jpg].freeze
  OPEN_THUMBS = %w[/digital-assets/thumbs/85827df9ab6c38d57468e763906aff80.jpg /digital-assets/thumbs/uac_1982_0022_2_pf.jpg].freeze

  # A record with two images of the given licence; extra fields override
  def stub_document(id, licence: "Public domain - Copyright expired", **extra)
    SolrDocument.new({ "id" => id, "title_tsim" => [ "Title of #{id}" ], "accession_number_ssim" => [ "ACC-#{id}" ],
                       "licence_type_ssim" => [ licence ], "digital_asset_large_paths_ssim" => OPEN_LARGE,
                       "digital_asset_paths_ssim" => OPEN_THUMBS }.merge(extra.transform_keys(&:to_s)))
  end

  def with_records(*documents)
    index = documents.index_by { |document| document.id.to_s }
    one = RecordLookup.instance_method(:find_record)
    many = RecordLookup.instance_method(:find_records)
    RecordLookup.send(:define_method, :find_record) { |id| index[id.to_s] || raise(ActionController::RoutingError, "Not Found") }
    RecordLookup.send(:define_method, :find_records) { |ids| Array(ids).map(&:to_s).uniq.filter_map { |id| index[id] } }
    RecordLookup.send(:private, :find_record, :find_records)
    yield
  ensure
    RecordLookup.send(:define_method, :find_record, one) if one
    RecordLookup.send(:define_method, :find_records, many) if many
    RecordLookup.send(:private, :find_record, :find_records)
  end
end
