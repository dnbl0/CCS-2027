require "test_helper"

class AccessRequestTest < ActiveSupport::TestCase
  def valid_request(**overrides)
    AccessRequest.new({ document_id: "emu-9044", document_title: "A fake record", request_type: "view", name: "Test Person",
                        email: "test.person@example.invalid", purpose: "Fake research purpose" }.merge(overrides))
  end

  test "a request with every required field is valid, and starts pending" do
    request = valid_request

    assert request.valid?, request.errors.full_messages.to_sentence
    assert_equal "pending", request.status
  end

  test "name, email, purpose and the record are required" do
    request = AccessRequest.new

    assert_not request.valid?
    %i[document_id document_title name email purpose].each { |field| assert request.errors.key?(field), "#{field} not required" }
    assert_equal [ "Enter your name" ], request.errors.messages_for(:name)
  end

  test "organisation is optional" do
    assert valid_request(organisation: nil).valid?
  end

  test "the email must look like an address" do
    assert_not valid_request(email: "not-an-address").valid?
    assert_equal [ "Enter your email address in the format name@example.com" ], valid_request(email: "x@").tap(&:valid?).errors.messages_for(:email)
  end

  test "the request type and status are one of the known values" do
    assert_not valid_request(request_type: "delete").valid?
    assert_not valid_request(status: "maybe").valid?
    %w[pending approved declined].each { |status| assert valid_request(status: status).valid? }
  end

  test "text longer than its limit is refused" do
    assert_not valid_request(name: "a" * 201).valid?
    assert_not valid_request(purpose: "a" * 2001).valid?
    assert valid_request(purpose: "a" * 2000).valid?
  end

  test "the request type follows the record's tier, and an open record needs none" do
    assert_equal "view", AccessRequest.request_type_for(:request)
    assert_equal "download", AccessRequest.request_type_for(:view_only)
    assert_nil AccessRequest.request_type_for(:open)
  end
end
