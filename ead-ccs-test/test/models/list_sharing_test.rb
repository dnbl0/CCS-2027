require "test_helper"

# Galleries: a list shared by an unguessable, revocable link (List#share!, .find_shared), copied for another visitor (#copy_for).
class ListSharingTest < ActiveSupport::TestCase
  setup do
    @user = User.create!
    @list = @user.lists.create!(name: "Violins", description: "  Strings   of the   Grainger ")
  end

  test "a list is not shared until its owner shares it" do
    assert_not @list.shared?
    assert_nil @list.share_token
    assert_nil List.find_shared("a" * 32)
  end

  test "the description is squished and an empty one is nil" do
    assert_equal "Strings of the Grainger", @list.description
    @list.update!(description: "   ")
    assert_nil @list.description
  end

  test "the description has a limit" do
    @list.description = "x" * (List::DESCRIPTION_LIMIT + 1)
    assert_not @list.valid?
    assert @list.errors.of_kind?(:description, :too_long)
  end

  test "sharing makes a 32 character URL-safe token from 192 random bits, and sharing again keeps it" do
    @list.share!
    token = @list.share_token

    assert_match List::TOKEN_FORMAT, token
    assert_equal 24, List::TOKEN_BYTES
    assert_equal 32, token.length
    assert_not_nil @list.shared_at
    assert_equal token, @list.share!.share_token
    assert_equal @list, List.find_shared(token)
  end

  test "tokens are not guessable: a thousand of them are all different, evenly spread, and nothing like the list's id or name" do
    tokens = Array.new(1000) { SecureRandom.urlsafe_base64(List::TOKEN_BYTES) }

    assert_equal 1000, tokens.uniq.size
    assert(tokens.all? { |token| token.match?(List::TOKEN_FORMAT) })
    characters = tokens.join.chars.tally
    assert_operator characters.size, :>=, 60, "the whole URL-safe alphabet is used"
    assert_operator characters.values.max, :<, 32_000 * 3 / 64, "no character is far more common than chance allows"
    @list.share!
    assert_not_includes @list.share_token, @list.id.to_s * 3
    assert_not_includes @list.share_token.downcase, "violins"
  end

  test "a new link replaces the old, which stops working" do
    old = @list.share!.share_token
    new = @list.share!(regenerate: true).share_token

    assert_not_equal old, new
    assert_nil List.find_shared(old)
    assert_equal @list, List.find_shared(new)
  end

  test "stopping sharing revokes the link" do
    token = @list.share!.share_token
    @list.unshare!

    assert_not @list.reload.shared?
    assert_nil @list.shared_at
    assert_nil List.find_shared(token)
  end

  test "a malformed, blank or other-sized token finds nothing, without asking the database" do
    @list.share!
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      [ nil, "", "short", "#{@list.share_token}x", @list.share_token.chop, "#{'!' * 32}", "%00" * 11 ].each { |token| assert_nil List.find_shared(token) }
    end
    assert_empty queries
  end

  test "deleting the list revokes the link" do
    token = @list.share!.share_token
    @list.destroy

    assert_nil List.find_shared(token)
  end

  test "Delete my data revokes every link of the visitor, and only theirs" do
    mine = @list.share!.share_token
    other = User.create!.lists.create!(name: "Theirs").share!.share_token
    session = { blacklight_guest_user_id: @user.id }
    assert_equal 1, MyData.new(session).counts[:shared_lists]

    MyData.new(session).delete!

    assert_nil List.find_shared(mine)
    assert_not_nil List.find_shared(other)
  end

  test "the cover must be one of the list's records" do
    @list.list_items.create!(document_id: "emu-1")
    @list.cover_document_id = "emu-2"
    assert_not @list.valid?
    assert @list.errors.of_kind?(:cover_document_id, :not_in_list)

    @list.cover_document_id = "emu-1"
    assert @list.valid?
    @list.cover_document_id = ""
    assert @list.save
    assert_nil @list.cover_document_id
  end

  test "a copy is a new unshared list of the other visitor with the same description and records, in the same order" do
    %w[a b c].each { |id| @list.list_items.create!(document_id: id) } # shown newest first: c, b, a
    @list.update!(cover_document_id: "b")
    token = @list.share!.share_token
    viewer = User.create!

    copy = @list.copy_for(viewer)

    assert copy.persisted?
    assert_equal viewer, copy.user
    assert_equal "Violins", copy.name
    assert_equal "Strings of the Grainger", copy.description
    assert_equal "b", copy.cover_document_id
    assert_not copy.shared?
    assert_not_equal token, copy.share_token
    assert_equal %w[c b a], copy.list_items.recent.pluck(:document_id)
    assert_equal %w[c b a], @list.list_items.recent.pluck(:document_id), "the original is unchanged"
  end

  test "a copy made by the owner, or by a visitor with that name already, gets a free name" do
    @list.share!
    first = @list.copy_for(@user)
    second = @list.copy_for(@user)

    assert_equal "Violins (2)", first.name
    assert_equal "Violins (3)", second.name
  end

  test "a long name still fits when a number is added" do
    list = @user.lists.create!(name: "n" * List::NAME_LIMIT)
    copy = list.copy_for(@user)

    assert copy.persisted?
    assert_operator copy.name.length, :<=, List::NAME_LIMIT
    assert copy.name.end_with?(" (2)")
  end

  test "a visitor who has the most lists allowed is not given another, and the copy says why" do
    viewer = User.create!
    List::MAX_PER_USER.times { |n| viewer.lists.create!(name: "List #{n}") }

    copy = @list.copy_for(viewer)

    assert_not copy.persisted?
    assert_includes copy.errors.full_messages.to_sentence, "at most #{List::MAX_PER_USER} lists"
    assert_equal List::MAX_PER_USER, viewer.lists.count
  end

  test "a list with the most records allowed copies in full" do
    ListItem::MAX_PER_LIST.times { |n| @list.list_items.create!(document_id: "r#{n}") }

    copy = @list.copy_for(User.create!)

    assert_equal ListItem::MAX_PER_LIST, copy.list_items.count
    assert copy.full?
  end
end
