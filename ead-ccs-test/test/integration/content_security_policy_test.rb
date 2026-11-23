require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "pages carry a report-only policy, so nothing is blocked yet" do
    get "/"

    assert_response :success
    assert_nil response.headers["Content-Security-Policy"]
    policy = response.headers["Content-Security-Policy-Report-Only"]
    assert_includes policy, "default-src 'self'"
    assert_includes policy, "object-src 'none'"
    assert_match(/script-src 'self' 'wasm-unsafe-eval' 'nonce-/, policy) # WebAssembly for the 3D viewer's decoders (CCS-164), not eval
    assert_not_includes policy, "'unsafe-eval'"
    assert_includes policy, "worker-src 'self' blob:"
    assert_includes policy, "connect-src 'self' https://unimelbourne.widen.net" # eBooks and 3D models are fetched from the DAM
  end

  test "the DAM's images and media may load: images from any https host, audio and video from this site and the DAM" do
    get "/"
    policy = response.headers["Content-Security-Policy-Report-Only"]

    assert_match(/img-src [^;]*https:/, policy)
    assert_match(%r{media-src 'self'[^;]* https://unimelbourne\.widen\.net}, policy)
  end
end
