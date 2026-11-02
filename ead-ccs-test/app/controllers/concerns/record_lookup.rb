# frozen_string_literal: true

# Finds records in the index for the controllers that act on a record without being the catalog (the sensitivity choice,
# the metadata export, the bulk download). A record that is not in the index is a 404.
module RecordLookup
  extend ActiveSupport::Concern

  private

  def find_record(id)
    id = id.to_s
    raise ActionController::RoutingError, "Not Found" if id.blank? || id.length > 200

    record_service.fetch(id) || raise(ActionController::RoutingError, "Not Found")
  rescue Blacklight::Exceptions::RecordNotFound
    raise ActionController::RoutingError, "Not Found"
  end

  # Records in the order asked for; an id that is not in the index is left out
  def find_records(ids)
    ids = Array(ids).map(&:to_s).uniq
    return [] if ids.empty?

    by_id = record_service.fetch(ids).index_by { |document| document.id.to_s }
    ids.filter_map { |id| by_id[id] }
  end

  def record_service
    config = CatalogController.blacklight_config
    SearchService.new(config: config, search_state: Blacklight::SearchState.new({}, config), user_params: {})
  end
end
