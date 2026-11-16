require "test_helper"

# CCS-56: the Chinese, Japanese and Korean search is offered only when the core has its fields.
class CjkIndexTest < ActiveSupport::TestCase
  def with_luke(answer)
    connection = Blacklight.default_index.connection
    asked = []
    connection.define_singleton_method(:get) do |path, **options|
      asked << [ path, options ]
      raise answer if answer.is_a?(Exception)

      answer
    end
    CjkIndex.probe = true
    yield asked
  ensure
    connection.singleton_class.send(:remove_method, :get)
    CjkIndex.probe = nil
  end

  test "it is off until Solr has said otherwise, and a page that does not ask Solr never asks" do
    assert_not CjkIndex.available?
  end

  test "the core's schema decides, and Solr is asked once in ten minutes" do
    with_luke({ "schema" => { "fields" => { "all_text_cjk" => {}, "id" => {} } } }) do |asked|
      assert CjkIndex.refresh!
      assert CjkIndex.refresh!
      assert CjkIndex.available?

      assert_equal 1, asked.size
      assert_equal [ "admin/luke", { params: { show: "schema", wt: "json" } } ], asked.first
    end
  end

  test "a core made before the CJK fields, or one that cannot be asked, is off" do
    with_luke({ "schema" => { "fields" => { "id" => {} } } }) { assert_not CjkIndex.refresh! }
    CjkIndex.force(nil)
    with_luke(Errno::ECONNREFUSED.new) { assert_not CjkIndex.refresh! }
  end

  test "tests never ask Solr unless they say so" do
    assert_not CjkIndex.refresh!
  end

  test "the search option and the Description search follow the answer" do
    field = CatalogController.blacklight_config.search_fields["cjk"]
    assert_not field.if.call(nil, field)
    assert_nil SearchBuilder.new(CatalogController.new).with(q: "x", search_field: "description").to_h[:qf].to_s[/description_qf/]

    CjkIndex.force(true)
    assert field.if.call(nil, field)
    assert_equal "${description_qf}", SearchBuilder.new(CatalogController.new).with(q: "x", search_field: "description").to_h[:qf]
    assert_not_equal "${description_qf}", SearchBuilder.new(CatalogController.new).with(q: "x", search_field: "title").to_h[:qf]
    assert_equal "${cjk_qf}", SearchBuilder.new(CatalogController.new).with(q: "x", search_field: "cjk").to_h[:qf]
  end
end
