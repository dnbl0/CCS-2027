require "test_helper"

# CCS-389: a visitor's named lists and the records in them.
class ListTest < ActiveSupport::TestCase
  setup { @user = User.create! }

  test "a list needs a name, tidied of extra spaces, of at most the limit" do
    assert_equal "Skulls and bones", @user.lists.create!(name: "  Skulls   and bones ").name
    assert_not @user.lists.build(name: " ").valid?
    assert_not @user.lists.build(name: "x" * (List::NAME_LIMIT + 1)).valid?
    assert @user.lists.build(name: "x" * List::NAME_LIMIT).valid?
  end

  test "a name is unique among the visitor's own lists, ignoring case, but another visitor may use it" do
    @user.lists.create!(name: "Violins")

    duplicate = @user.lists.build(name: "violins")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
    assert User.create!.lists.build(name: "Violins").valid?
  end

  test "a visitor may have at most MAX_PER_USER lists" do
    List::MAX_PER_USER.times { |n| @user.lists.create!(name: "List #{n}") }

    extra = @user.lists.build(name: "One too many")
    assert_not extra.valid?
    assert_includes extra.errors.full_messages, "You can have at most #{List::MAX_PER_USER} lists. Delete one to make a new one."
  end

  test "a record is in a list once, and a list holds at most MAX_PER_LIST records" do
    list = @user.lists.create!(name: "Violins")
    list.list_items.create!(document_id: "a1")

    assert_not list.list_items.build(document_id: "a1").valid?
    assert_not list.list_items.build(document_id: "").valid?

    now = Time.current
    ListItem.insert_all((1..ListItem::MAX_PER_LIST - 1).map { |n| { list_id: list.id, document_id: "bulk#{n}", created_at: now, updated_at: now } })
    full = list.list_items.build(document_id: "b2")
    assert_not full.valid?
    assert_includes full.errors.full_messages, "A list can hold at most #{ListItem::MAX_PER_LIST} records. Remove one to add another."
  end

  test "deleting a list deletes its items, and deleting the visitor deletes their lists" do
    list = @user.lists.create!(name: "Violins")
    list.list_items.create!(document_id: "a1")

    assert_difference [ "List.count", "ListItem.count" ], -1 do
      @user.destroy
    end
  end

  test "lists are alphabetical ignoring case" do
    %w[beta Alpha gamma].each { |name| @user.lists.create!(name: name) }

    assert_equal %w[Alpha beta gamma], @user.lists.by_name.map(&:name)
  end
end
