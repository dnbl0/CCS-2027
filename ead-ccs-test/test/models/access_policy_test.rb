require "test_helper"

class AccessPolicyTest < ActiveSupport::TestCase
  def tier_for(*licences) = AccessPolicy.tier(SolrDocument.new("id" => "x", "licence_type_ssim" => licences))

  EXPECTED = {
    "Public domain - Copyright expired" => :open,
    "Copyright - Current" => :view_only,
    "Copyright" => :view_only,
    "Reproduction Licence - Current" => :view_only,
    "Reproduction Licence - Requested" => :view_only,
    "Reproduction Licence - The University of Melbourne" => :view_only,
    "Reproduction Licence - Restricted" => :request,
    "Restricted Access" => :request,
    "ICIP Rights" => :request
  }.freeze

  EXPECTED.each do |licence, tier|
    test "#{licence} is #{tier}" do
      assert_equal tier, tier_for(licence)
    end
  end

  test "every tier is one of TIERS" do
    assert_empty EXPECTED.values.uniq - AccessPolicy::TIERS
    assert_equal AccessPolicy::TIERS.sort, EXPECTED.values.uniq.sort
  end

  test "case and spacing do not matter" do
    assert_equal :open, tier_for("  public DOMAIN - copyright expired ")
    assert_equal :request, tier_for("icip rights")
  end

  test "a blank or missing licence is view_only: viewable, never downloadable" do
    assert_equal :view_only, AccessPolicy.tier(SolrDocument.new("id" => "x"))
    assert_equal :view_only, tier_for("")
    assert_equal :view_only, tier_for
  end

  test "a licence the rules do not know is view_only" do
    assert_equal :view_only, tier_for("Something new")
  end

  test "a restriction in a new wording is still withheld" do
    assert_equal :request, tier_for("Reproduction Licence - Restricted (Elders)")
    assert_equal :request, tier_for("Culturally restricted")
  end

  test "with several licences the most restrictive wins" do
    assert_equal :request, tier_for("Public domain - Copyright expired", "ICIP Rights")
    assert_equal :view_only, tier_for("Public domain - Copyright expired", "Copyright - Current")
  end

  test "download? is for open only; view? is for open and view_only" do
    open = SolrDocument.new("id" => "o", "licence_type_ssim" => [ "Public domain - Copyright expired" ])
    view = SolrDocument.new("id" => "v", "licence_type_ssim" => [ "Copyright" ])
    request = SolrDocument.new("id" => "r", "licence_type_ssim" => [ "Restricted Access" ])

    assert_equal [ true, true, false ], [ open, view, request ].map { |doc| AccessPolicy.view?(doc) }
    assert_equal [ true, false, false ], [ open, view, request ].map { |doc| AccessPolicy.download?(doc) }
  end

  test "request_path is the access request form for the record" do
    assert_equal "/access_requests/new?document_id=emu-1%2F2", AccessPolicy.request_path(SolrDocument.new("id" => "emu-1/2"))
  end
end
