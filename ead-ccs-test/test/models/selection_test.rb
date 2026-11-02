require "test_helper"

# CCS-40: the records ticked on the results pages, in the session cookie, in the order chosen.
class SelectionTest < ActiveSupport::TestCase
  def selection(session = {}) = Selection.new(session)

  test "records are kept in the order they were chosen, each once" do
    chosen = selection
    chosen.add(%w[b a])
    chosen.add(%w[c a b])

    assert_equal %w[b a c], chosen.ids
    assert_equal 3, chosen.count
    assert_equal 1, chosen.position("b")
    assert_equal 3, chosen.position("c")
    assert_nil chosen.position("zzz")
  end

  test "at most 50 are kept, and the ones that did not fit are reported, not dropped silently" do
    chosen = selection
    refused = chosen.add((1..60).map { |n| "rec-#{n}" })

    assert_equal 50, chosen.count
    assert_predicate chosen, :full?
    assert_equal (51..60).map { |n| "rec-#{n}" }, refused
    assert_equal [ "rec-60" ], chosen.add([ "rec-60" ])
    assert_empty chosen.add([ "rec-1" ]), "a record already chosen is not refused"
  end

  test "ticking and unticking within a page changes that page only" do
    chosen = selection
    chosen.add(%w[other-page])
    chosen.sync(scope: %w[a b c], chosen: %w[c a])
    assert_equal %w[other-page c a], chosen.ids

    chosen.sync(scope: %w[a b c], chosen: %w[a])
    assert_equal %w[other-page a], chosen.ids
  end

  test "sync ignores ticks for records outside the page it was told about" do
    chosen = selection
    chosen.sync(scope: %w[a], chosen: %w[a intruder])

    assert_equal %w[a], chosen.ids
  end

  test "clear empties it, and remove takes some out" do
    chosen = selection
    chosen.add(%w[a b c])
    chosen.remove(%w[b])
    assert_equal %w[a c], chosen.ids

    chosen.clear
    assert_empty chosen.ids
    assert_predicate chosen, :empty?
  end

  test "previous and next follow the order chosen" do
    chosen = selection
    chosen.add(%w[a b c])

    assert_nil chosen.previous_id("a")
    assert_equal "c", chosen.next_id("b")
    assert_equal "a", chosen.previous_id("b")
    assert_nil chosen.next_id("c")
    assert_nil chosen.next_id("unknown")
  end

  test "a damaged cookie is read as the ids that are plausible" do
    session = { Selection::KEY => [ "a", 7, nil, "", "a", "x" * 300, { "id" => "h" }, "b" ] }

    assert_equal %w[a b], selection(session).ids
    assert_empty selection(Selection::KEY => "not a list").ids
    assert_empty selection.ids
  end

  test "keep_only drops records that are no longer in the index" do
    chosen = selection
    chosen.add(%w[a b c])
    chosen.keep_only(%w[c a])

    assert_equal %w[a c], chosen.ids
  end

  test "the largest selection fits in the cookie beside the largest set of sensitivity choices" do
    long = "vernon-516-" + ("9" * 12) # the longest ids in the index are about 20 characters; this is longer
    session = { Selection::KEY => (1..Selection::MAX).map { |n| "#{long}#{n}"[0, 30] },
                Sensitivity::Choices::KEY => (1..Sensitivity::Choices::MAX_CHOICES).to_h { |n| [ "#{long}#{n}"[0, 30], "view" ] },
                blacklight_guest_user_id: 1_000_000, session_id: SecureRandom.hex(16), "_csrf_token" => SecureRandom.base64(32) }
    cookie = ActiveSupport::MessageEncryptor.new(SecureRandom.random_bytes(32), cbc_hmac: false, serializer: JSON)
                                            .encrypt_and_sign(session.as_json)

    assert_operator [ cookie.bytesize, "_ccs_session=".bytesize ].sum, :<, 4096, "the session cookie would be refused by browsers"
  end
end
