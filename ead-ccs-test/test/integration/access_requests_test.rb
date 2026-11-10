require "test_helper"

# CCS-69: asking for access to a record without a login. The record comes from the Solr core at SOLR_URL (docs/solr-dev.md);
# AccessPolicy is stubbed, as the classification is not in the index yet. All the people and addresses here are fake.
class AccessRequestsTest < ActionDispatch::IntegrationTest
  DOC = "emu-9044"
  PARAMS = { name: "Test Person", email: "test.person@example.invalid", organisation: "Example Org", purpose: "Fake research purpose" }.freeze

  setup do
    AccessRequestsController::RATE_STORE.clear
    @tier = :request
    test = self
    AccessPolicy.singleton_class.alias_method :__real_tier, :tier
    AccessPolicy.define_singleton_method(:tier) { |_document| test.instance_variable_get(:@tier) }
  end

  teardown do
    AccessPolicy.singleton_class.alias_method :tier, :__real_tier
    AccessPolicy.singleton_class.remove_method :__real_tier
  end

  def submit(overrides = {}, document_id: DOC, extra: {})
    post "/access_requests", params: { document_id: document_id, access_request: PARAMS.merge(overrides) }.merge(extra)
  end

  test "the form names the record and what is requested, with labelled, described fields" do
    needs_solr
    get AccessPolicy.request_path(SolrDocument.new(id: DOC))

    assert_response :success
    assert_select "h1", "Request access"
    assert_select "dd a[href='/catalog/#{DOC}']"
    assert_select "dd", text: "Permission to view this record"
    assert_select "dt", text: "Collection and ID"
    assert_select "dd[data-testid=record-identifier]", text: /UoM ID emu-umc-9044\z/
    assert_select "label[for=access_request_name]", text: /Your name/
    assert_select "input#access_request_name[autocomplete=name][required][aria-required=true]"
    assert_select "input#access_request_email[type=email][autocomplete=email][aria-describedby=access_request_email-hint]"
    assert_select "input#access_request_organisation:not([required])"
    assert_select "textarea#access_request_purpose[required]"
    assert_select "#privacy-title"
    assert_select ".access-form__summary", count: 0
  end

  test "a view-only record is asked for as a download" do
    needs_solr
    @tier = :view_only
    get "/access_requests/new", params: { document_id: DOC }

    assert_select "dd", text: "A copy of this record to download"
  end

  test "an open record has nothing to request, so the visitor goes to it" do
    needs_solr
    @tier = :open
    get "/access_requests/new", params: { document_id: DOC }

    assert_redirected_to "/catalog/#{DOC}"
  end

  test "an unknown or missing record is a 404" do
    needs_solr
    get "/access_requests/new", params: { document_id: "no-such-record-xyz" }
    assert_response :not_found
    get "/access_requests/new"
    assert_response :not_found
    submit({}, document_id: "no-such-record-xyz")
    assert_response :not_found
    assert_equal 0, AccessRequest.count
  end

  test "sending the form stores the request with the title read from the index, and shows a confirmation" do
    needs_solr
    assert_difference "AccessRequest.count", 1 do
      submit({}, extra: { document_title: "Forged title", request_type: "download", status: "approved" })
    end

    request = AccessRequest.last
    assert_equal "view", request.request_type
    assert_equal "pending", request.status
    assert_not_equal "Forged title", request.document_title
    assert request.document_title.present?
    assert_match(/UoM ID emu-umc-9044\z/, request.document_identifier)
    assert_redirected_to "/access_requests/#{request.id}"

    follow_redirect!
    assert_response :success
    assert_select "h1", "Request sent"
    assert_select "dd", text: PARAMS[:email]
    assert_select "dd", text: request.document_title
    assert_select "dd[data-testid=record-identifier]", text: request.document_identifier
    assert_select "h2", text: "What happens next"
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "an invalid form is shown again with a summary and a message beside each field, and keeps what was typed" do
    needs_solr
    assert_no_difference "AccessRequest.count" do
      submit({ name: "", email: "nope", purpose: "" })
    end

    assert_response :unprocessable_content
    assert_select ".access-form__summary[tabindex='-1'][autofocus] h2", "There is a problem"
    assert_select ".access-form__summary a[href='#access_request_name']", text: "Enter your name"
    assert_select ".access-form__summary li", count: 3
    assert_select "input#access_request_name[aria-invalid=true][aria-describedby='access_request_name-hint access_request_name-error']"
    assert_select "#access_request_email-error", text: /Enter your email address in the format/
    assert_select "input#access_request_email[value=nope]"
    assert_select "input#access_request_organisation[value='Example Org']"
  end

  test "a confirmation can be opened only by the browser that made the request" do
    needs_solr
    other = AccessRequest.create!(document_id: DOC, document_title: "T", request_type: "view", name: "Fake", email: "a@example.invalid", purpose: "p")

    get "/access_requests/#{other.id}"
    assert_response :not_found

    submit
    get "/access_requests/#{other.id}"
    assert_response :not_found
  end

  test "a filled-in trap field stores nothing" do
    needs_solr
    assert_no_difference "AccessRequest.count" do
      submit({}, extra: { website: "http://spam.example.invalid" })
    end
    assert_redirected_to "/catalog/#{DOC}"
  end

  test "one address may send only a few requests an hour" do
    needs_solr
    AccessRequestsController::RATE_LIMIT.times { |n| submit({ purpose: "Fake research purpose #{n}" }) }
    assert_equal AccessRequestsController::RATE_LIMIT, AccessRequest.count

    assert_no_difference "AccessRequest.count" do
      submit({ purpose: "Fake research purpose again" })
    end
    assert_response :too_many_requests
    assert_select ".access-form__summary", count: 0
    assert_select "input#access_request_name[value='Test Person']"
    assert_match(/Too many requests/, response.body)
  end

  test "a request with no access_request parameters is a bad request, not an error" do
    needs_solr
    post "/access_requests", params: { document_id: DOC }
    assert_response :bad_request
  end
end
