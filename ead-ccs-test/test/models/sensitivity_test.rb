require "test_helper"

class SensitivityTest < ActiveSupport::TestCase
  def doc(fields = {}) = SolrDocument.new({ "id" => "x" }.merge(fields))

  test "a restriction note that says sensitive makes a record sensitive" do
    assert Sensitivity.sensitive?(doc("restrictions_tsi" => "Not for publishing Sensitive|Culturally sensitive images. Only select images to be published online"))
    assert Sensitivity.sensitive?(doc("restrictions_tsi" => [ "Contains SENSITIVE images" ]))
  end

  test "Community Restricted access is not a sensitive choice: AccessPolicy withholds it" do
    assert_not Sensitivity.sensitive?(doc("access_condition_ssi" => "Community Restricted"))
  end

  test "other notes, other access conditions and no fields are not sensitive" do
    assert_not Sensitivity.sensitive?(doc("restrictions_tsi" => "Not for publishing Image|low res image"))
    assert_not Sensitivity.sensitive?(doc("access_condition_ssi" => "Consult"))
    assert_not Sensitivity.sensitive?(doc("restrictions_tsi" => "insensitive handling"))
    assert_not Sensitivity.sensitive?(doc)
  end

  test "choices are per record, and the latest choice wins" do
    choices = Sensitivity::Choices.new(session = {})
    assert_not choices.viewing?("a")
    assert_not choices.declined?("a")

    choices.record("a", "view")
    choices.record("b", "hide")
    assert choices.viewing?("a")
    assert choices.declined?("b")

    choices.record("a", "hide")
    assert choices.declined?("a")
    assert_equal %w[b a], session[Sensitivity::Choices::KEY].keys
  end

  test "a value that is not view or hide is not stored, and a damaged session is ignored" do
    session = { Sensitivity::Choices::KEY => "junk" }
    choices = Sensitivity::Choices.new(session)
    choices.record("a", "maybe")
    assert_equal "junk", session[Sensitivity::Choices::KEY]
    assert_not choices.viewing?("a")

    session[Sensitivity::Choices::KEY] = { "a" => "view", "b" => "evil", 3 => "view" }
    assert choices.viewing?("a")
    assert_not choices.viewing?("b")
  end

  test "only the latest choices are kept, so the cookie stays small" do
    choices = Sensitivity::Choices.new(session = {})
    (Sensitivity::Choices::MAX_CHOICES + 5).times { |n| choices.record("r#{n}", "view") }

    assert_equal Sensitivity::Choices::MAX_CHOICES, session[Sensitivity::Choices::KEY].size
    assert_not choices.viewing?("r0")
    assert choices.viewing?("r44")
  end
end
