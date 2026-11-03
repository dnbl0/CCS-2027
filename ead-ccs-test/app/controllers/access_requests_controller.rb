# frozen_string_literal: true

# Asking for access to a record (CCS-69), without a login: to view a record that is not licensed, or to download one
# that is view-only. The form is linked from the notices on the record pages (AccessPolicy.request_path); a request is
# stored for staff (bin/rails access_requests:export). No email is sent. SSO login and the approval screens come later.
class AccessRequestsController < ApplicationController
  include Blacklight::SearchContext # the header's Search results link goes back to the visitor's last search

  layout "pages"

  # How many requests one address may make an hour, and the memory they are counted in. (Rails.cache is a null store in
  # tests, and the count only has to hold for one server process.)
  RATE_LIMIT = 5
  # RATE_LIMIT_STORE=cache counts in Rails.cache instead, which several instances can share (CACHE_STORE; docs/availability-reliability-scalability.md)
  RATE_STORE = ENV["RATE_LIMIT_STORE"] == "cache" ? Rails.cache : ActiveSupport::Cache::MemoryStore.new

  before_action :load_document, only: %i[new create]
  rate_limit to: RATE_LIMIT, within: 1.hour, only: :create, store: RATE_STORE, with: :too_many_requests

  def new
    @access_request = AccessRequest.new
  end

  def create
    # The hidden field only a script fills in: say nothing, store nothing
    return redirect_to(solr_document_path(@document.id)) if params[:website].present?

    @access_request = AccessRequest.submit(access_request_params.merge(
      document_id: @document.id, document_title: document_title, request_type: @request_type
    ))
    if @access_request.persisted?
      # The confirmation shows the requester's details, so only the browser that made the request may open it
      session[:access_request_ids] = (Array(session[:access_request_ids]) + [ @access_request.id ]).uniq.last(20)
      redirect_to access_request_path(@access_request)
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    raise ActionController::RoutingError, "Not Found" unless Array(session[:access_request_ids]).include?(params[:id].to_i)

    @access_request = AccessRequest.find(params[:id])
    response.headers["Cache-Control"] = "no-store"
  end

  private

  def access_request_params = params.expect(access_request: %i[name email organisation purpose])

  # The record asked about must be in the index; its title is read here, never taken from the form. A record that is
  # open has nothing to request, so the visitor goes to it.
  def load_document
    id = params[:document_id].to_s
    raise ActionController::RoutingError, "Not Found" if id.blank? || id.length > 200

    config = CatalogController.blacklight_config
    service = SearchService.new(config: config, search_state: Blacklight::SearchState.new({}, config), user_params: {})
    @document = service.fetch(id)
    raise ActionController::RoutingError, "Not Found" unless @document
    @request_type = AccessRequest.request_type_for(AccessPolicy.tier(@document))
    redirect_to solr_document_path(@document.id) unless @request_type
  rescue Blacklight::Exceptions::RecordNotFound
    raise ActionController::RoutingError, "Not Found"
  end

  def document_title = helpers.document_presenter(@document).heading.to_s.truncate(500)

  def too_many_requests
    @access_request = AccessRequest.new(access_request_params)
    flash.now[:alert] = t("nexus_ccs.access_requests.too_many")
    render :new, status: :too_many_requests
  end
end
