require "test_helper"
require_relative "../support/outages"

# What a visitor sees when something fails: a page in the site header and footer, in plain words, with what to do next
# (ErrorsController), instead of Rails' stock page. No Solr is needed for these.
class ErrorPagesTest < ActionDispatch::IntegrationTest
  include Outages

  test "an unknown address is a 404 in the site chrome, with what to do next" do
    as_production { get "/no-such-page" }

    assert_response :not_found
    assert_select ".site-header"
    assert_select ".site-footer"
    assert_select ".page-banner h1", "Page not found"
    assert_select ".error-page__lead", /mistyped/
    assert_select ".error-page__links a", text: "Search all records"
    assert_select ".error-page__links a[href='/collections']", count: 0
    assert_select ".error-page__links a", text: "Go to the home page"
    assert_select ".error-page__help a[href=?]", "/help#contact-us"
    assert_select ".error-page__code", "Error 404"
  end

  test "an unknown record is a 404 about the record, not about a page" do
    as_production { get "/stock/no-such-record" }

    assert_response :not_found
    assert_select ".page-banner h1", "We can't find this record"
    assert_select ".error-page__lead", /withdrawn/
  end

  test "an unreadable address is a 400 with its own wording" do
    as_production { get "/catalog?q=%E0%A4%A" }

    assert_response :bad_request
    assert_select ".page-banner h1", "We couldn't read that address"
  end

  test "an unexpected failure is a 500 that offers to try the page again, and shows no detail" do
    original = HelpTopic.method(:find)
    HelpTopic.define_singleton_method(:find) { |*| raise "boom: secret detail" }
    begin
      as_production { get "/help?topic=anything" }
    ensure
      HelpTopic.define_singleton_method(:find, original)
    end

    assert_response :internal_server_error
    assert_select ".page-banner h1", "Something went wrong"
    assert_select ".error-page__links a[href=?]", "/help?topic=anything", text: "Try this page again"
    assert_no_match(/boom|secret detail|backtrace/i, response.body)
  end

  # Each status the site can answer with, as the page in the site chrome: its title, what to do next, the code, noindex, and the
  # headers that tell a client when to come back
  {
    "400" => "We couldn't read that address", "404" => "Page not found", "406" => "We can't show it that way",
    "422" => "Your request couldn't be completed", "429" => "Too many requests", "500" => "Something went wrong",
    "503" => "The service is busy or unavailable"
  }.each do |code, title|
    test "the #{code} page is in the site chrome with its own words, a way on, and no indexing" do
      with_error_page(code) { get "/help" }

      assert_response code.to_i
      assert_select ".site-header"
      assert_select ".site-footer"
      assert_select "main#main-content"
      assert_select ".page-banner h1", title
      assert_select ".error-page__lead"
      assert_select ".error-page__links a", text: "Go to the home page"
      assert_select ".error-page__help a[href=?]", "/help#contact-us"
      assert_select ".error-page__code", "Error #{code}"
      assert_match(/noindex/, response.headers["X-Robots-Tag"].to_s)
      retry_after = ErrorsController::RETRY_AFTER[code]
      retry_after ? assert_equal(retry_after.to_s, response.headers["Retry-After"]) : assert_nil(response.headers["Retry-After"])
    end
  end

  test "a 503 and a 429 offer to try again" do
    with_error_page("503") { get "/help" }
    assert_select ".error-page__links a[href='/help']", text: "Try this page again"

    with_error_page("429") { get "/help" }
    assert_select ".error-page__links a[href='/help']", text: "Try this page again"
  end

  test "a database that cannot be reached is a 503, and Solr too, never a 500" do
    assert_equal :service_unavailable, ActionDispatch::ExceptionWrapper.rescue_responses["ActiveRecord::ConnectionNotEstablished"]
    assert_equal :service_unavailable, ActionDispatch::ExceptionWrapper.rescue_responses["ActiveRecord::ConnectionTimeoutError"]
    assert_equal :service_unavailable, ActionDispatch::ExceptionWrapper.rescue_responses["Blacklight::Exceptions::RepositoryTimeout"]
    assert_equal :service_unavailable, ActionDispatch::ExceptionWrapper.rescue_responses["Faraday::ConnectionFailed"]
  end

  test "when the page itself cannot be drawn the stock file is sent, with the same status" do
    original = ErrorsController.instance_method(:show)
    ErrorsController.define_method(:show) { raise "layout broke" }
    begin
      with_error_page("503") { get "/help" }
    ensure
      ErrorsController.define_method(:show, original)
    end

    assert_response :service_unavailable
    assert_match(/The service is busy or unavailable/, response.body)
    assert_equal "30", response.headers["Retry-After"]
  end

  %w[400 404 422 429 500 503].each do |code|
    test "the stock public/#{code}.html is a complete page: language, title, landmark, noindex, a way home" do
      html = Rails.public_path.join("#{code}.html").read

      assert_match(/<html lang="en">/, html)
      assert_match(/<title>[^<]+<\/title>/, html)
      assert_match(/<main/, html)
      assert_match(/<h1|<svg/, html)
      assert_match(/noindex/, html)
    end
  end

  test "the layouts tell a visitor with JavaScript turned off what still works" do
    get "/help"

    assert_includes response.body, "<noscript>"
    assert_match(/JavaScript is turned off/, response.body)
    assert_match(%r{href="/catalog\?search_field=all_fields">search all records}, response.body)
  end
end
