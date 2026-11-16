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

  def dam_doc(*licences, **extra)
    SolrDocument.new({ "id" => "d", "digital_asset_metadata_ssm" => licences.map { |l| { "licence" => l }.to_json } }.merge(extra.stringify_keys))
  end

  test "the DAM licence decides the tier" do
    assert_equal :open, AccessPolicy.tier(dam_doc("CC BY"))
    assert_equal :view_only, AccessPolicy.tier(dam_doc("All Rights reserved (UoM)"))
    assert_equal :view_only, AccessPolicy.tier(dam_doc("Copyright Agency Limited"))
    assert_equal :view_only, AccessPolicy.tier(dam_doc("Individual"))
  end

  test "a DAM licence overrides a more open EMu licence" do
    doc = dam_doc("All Rights reserved (UoM)", licence_type_ssim: [ "Public domain - Copyright expired" ])
    assert_equal :view_only, AccessPolicy.tier(doc)
  end

  test "a DAM licence overrides a more restrictive EMu copyright licence" do
    assert_equal :open, AccessPolicy.tier(dam_doc("CC BY", licence_type_ssim: [ "Copyright - Current" ]))
  end

  test "an asset with no DAM licence is not shown" do
    assert_equal :request, AccessPolicy.tier(dam_doc("None"))
    assert_equal :request, AccessPolicy.tier(dam_doc(""))
    assert_equal :request, AccessPolicy.tier(SolrDocument.new("id" => "d", "digital_asset_metadata_ssm" => [ { "producer" => "x" }.to_json ]))
  end

  test "with several assets the most restrictive DAM licence wins" do
    assert_equal :view_only, AccessPolicy.tier(dam_doc("CC BY", "Individual"))
    assert_equal :request, AccessPolicy.tier(dam_doc("CC BY", "None"))
  end

  test "EMu restrictions still withhold whatever the DAM says" do
    assert_equal :request, AccessPolicy.tier(dam_doc("CC BY", licence_type_ssim: [ "ICIP Rights" ]))
    assert_equal :request, AccessPolicy.tier(dam_doc("CC BY", access_condition_ssi: "Community Restricted"))
  end

  test "a DAM licence that says restricted is withheld" do
    assert_equal :request, AccessPolicy.tier(dam_doc("Restricted - Elders"))
  end

  test "unreadable DAM metadata falls back to the EMu licence" do
    doc = SolrDocument.new("id" => "d", "digital_asset_metadata_ssm" => [ "not json" ], "licence_type_ssim" => [ "Copyright" ])
    assert_equal :view_only, AccessPolicy.tier(doc)
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

  test "Community Restricted access withholds the asset whatever the licence and the case" do
    [ [], [ "Public domain - Copyright expired" ], [ "Copyright" ] ].each do |licences|
      doc = SolrDocument.new("id" => "c", "licence_type_ssim" => licences, "access_condition_ssi" => " community restricted ")

      assert_equal :request, AccessPolicy.tier(doc), licences.inspect
    end
    assert_equal :open, AccessPolicy.tier(SolrDocument.new("id" => "o", "licence_type_ssim" => [ "Public domain - Copyright expired" ], "access_condition_ssi" => "Consult"))
  end
end
