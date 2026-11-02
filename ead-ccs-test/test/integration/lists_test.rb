require "test_helper"

# CCS-389, CCS-129, CCS-136: a visitor's named lists. The owner is the guest user of the session cookie, created on the
# first list, as for saved records and saved searches.
class ListsTest < ActionDispatch::IntegrationTest
  def make_list(name)
    post "/lists", params: { list: { name: name } }
    List.order(:id).last
  end

  test "the lists page is empty, and creates no guest, until a list is made" do
    assert_no_difference "User.count" do
      get "/lists"
    end

    assert_response :success
    assert_select "h1", text: "Your lists"
    assert_select ".saved-empty__text", text: /not made any lists/
    assert_select "a[href='/lists/new']"
  end

  test "making a list creates the guest and opens the list with a notice" do
    assert_difference [ "User.count", "List.count" ], 1 do
      post "/lists", params: { list: { name: "Violins" } }
    end
    follow_redirect!

    assert_response :success
    assert_select "h1", text: "Violins"
    assert_select "[role=status], .alert", text: /List Violins created\./
    assert_select ".saved-empty__text", text: /no records yet/
  end

  test "a list needs a name, and the form says what is wrong, with the limits in the hint" do
    get "/lists/new"
    assert_select "label[for=list_name]", text: "List name"
    assert_select "#list-name-hint", text: /Up to #{List::NAME_LIMIT} characters.*#{List::MAX_PER_USER} lists.*#{ListItem::MAX_PER_LIST} records/

    assert_no_difference "List.count" do
      post "/lists", params: { list: { name: " " } }
    end

    assert_response :unprocessable_content
    assert_select ".alert[tabindex='-1'][data-controller=focus-on-load] a[href='#list_name']", text: /Name can.t be blank/
    assert_select "input#list_name[aria-invalid=true][aria-describedby~=list-name-error][aria-describedby~=list-name-hint]"
  end

  test "a name already used is refused, ignoring case" do
    make_list("Violins")

    assert_no_difference "List.count" do
      post "/lists", params: { list: { name: "violins" } }
    end

    assert_response :unprocessable_content
    assert_select ".alert", text: /already been taken/
  end

  test "the lists page lists them alphabetically with their record counts and named Rename and Delete buttons" do
    make_list("beta").list_items.create!(document_id: "a1")
    make_list("Alpha")

    get "/lists"

    assert_select "table.lists caption.visually-hidden", text: "Your lists"
    assert_select "table.lists tbody th a", count: 2
    assert_equal %w[Alpha beta], css_select("table.lists tbody th a").map(&:text)
    assert_select "table.lists tbody tr:nth-child(2) td:nth-child(2)", text: "1"
    assert_select "a.history-action[href='/lists/#{List.find_by(name: 'Alpha').id}/edit'] .visually-hidden", text: "Rename list: Alpha"
    assert_select "form button.history-action .visually-hidden", text: "Delete list: Alpha"
    assert_select "button[data-turbo-confirm=?]", "Delete the list Alpha? Its records stay in the collection."
  end

  test "a list is renamed, and a refused name keeps the form" do
    list = make_list("Violins")
    make_list("Cellos")

    get "/lists/#{list.id}/edit"
    assert_select "input#list_name[value=Violins]"

    patch "/lists/#{list.id}", params: { list: { name: "Cellos" } }
    assert_response :unprocessable_content

    patch "/lists/#{list.id}", params: { list: { name: "Violas" } }
    assert_redirected_to "/lists/#{list.id}"
    assert_equal "Violas", list.reload.name
  end

  test "a list is deleted with its items, and focus and the notice land on the lists page" do
    list = make_list("Violins")
    list.list_items.create!(document_id: "a1")

    assert_difference [ "List.count", "ListItem.count" ], -1 do
      delete "/lists/#{list.id}"
    end
    follow_redirect!

    assert_select "h2[tabindex='-1'][data-controller=focus-on-load]", text: "0 lists"
    assert_select "[role=status], .alert", text: /List Violins deleted\./
  end

  test "a record is added to a list from where it is, and removed again, going back to that page" do
    list = make_list("Violins")

    post "/lists/#{list.id}/items", params: { document_id: "a1" }, headers: { "HTTP_REFERER" => "http://www.example.com/catalog?q=x" }
    assert_redirected_to "/catalog?q=x"
    assert_equal [ "a1" ], list.list_items.pluck(:document_id)

    post "/lists/#{list.id}/items", params: { document_id: "a1" }
    assert_equal 1, list.list_items.count, "adding a record twice keeps one"

    delete "/lists/#{list.id}/items/#{list.list_items.first.id}"
    assert_redirected_to "/lists"
    assert_equal 0, list.list_items.count
  end

  test "a new list can be made with the record in it from the menu" do
    assert_difference [ "List.count", "ListItem.count" ], 1 do
      post "/lists", params: { list: { name: "Violins" }, document_id: "a1" }, headers: { "HTTP_REFERER" => "http://www.example.com/catalog?q=x" }
    end

    assert_redirected_to "/catalog?q=x"
    assert_equal [ "a1" ], List.last.list_items.pluck(:document_id)
  end

  test "a refused new list from the menu goes back with the reason" do
    make_list("Violins")

    assert_no_difference "List.count" do
      post "/lists", params: { list: { name: "Violins" }, document_id: "a1" }
    end

    assert_redirected_to "/lists"
    follow_redirect!
    assert_select ".alert, [role=alert]", text: /already been taken/
  end

  test "a visitor has at most MAX_PER_USER lists and a list at most MAX_PER_LIST records" do
    List::MAX_PER_USER.times { |n| make_list("List #{n}") }
    post "/lists", params: { list: { name: "One too many" } }
    assert_response :unprocessable_content
    assert_select ".alert", text: /at most #{List::MAX_PER_USER} lists/

    list = List.first
    now = Time.current
    ListItem.insert_all((1..ListItem::MAX_PER_LIST).map { |n| { list_id: list.id, document_id: "bulk#{n}", created_at: now, updated_at: now } })
    post "/lists/#{list.id}/items", params: { document_id: "extra" }
    assert_not list.list_items.exists?(document_id: "extra")
  end

  test "another visitor's list cannot be seen, renamed, deleted or added to" do
    theirs = List.create!(user: User.create!, name: "Theirs")
    make_list("Mine")

    get "/lists/#{theirs.id}"
    assert_redirected_to "/lists"
    patch "/lists/#{theirs.id}", params: { list: { name: "Hijacked" } }
    delete "/lists/#{theirs.id}"
    post "/lists/#{theirs.id}/items", params: { document_id: "a1" }

    assert_equal "Theirs", theirs.reload.name
    assert_equal 0, theirs.list_items.count
  end

  test "the saved records page links to Your lists" do
    needs_solr
    get "/bookmarks"

    assert_select "a[href='/lists']", text: "Your lists"
  end

  # The pages below read the Solr core at SOLR_URL; the "rails" CI job has none, so they skip themselves
  def needs_solr
    Blacklight.default_index.connection.get("select", params: { q: "*:*", rows: 0 })
  rescue StandardError
    skip "needs the Solr core at SOLR_URL"
  end

  def first_ids(count)
    get "/catalog", params: { q: "skull", any_assets: "1", format: :json }
    JSON.parse(response.body)["data"].first(count).map { |doc| doc["id"] }
  end

  test "a list shows its records as result cards, newest added first, each with the Add to list menu" do
    needs_solr
    older, newer = first_ids(2)
    list = make_list("Skulls")
    list.list_items.create!(document_id: older, created_at: 2.days.ago)
    list.list_items.create!(document_id: newer)
    list.list_items.create!(document_id: "gone-from-the-index")

    get "/lists/#{list.id}"

    assert_response :success
    assert_select "h1", text: "Skulls"
    assert_select ".saved-toolbar__count", text: "3 records"
    assert_equal [ newer, older ].map(&:parameterize), css_select(".result-card").map { |card| card["data-document-id"] }
    assert_select ".saved-lists-note", text: /no longer in the collection/
    assert_select ".result-card .list-menu__item--in", text: /Remove from Skulls/
  end

  test "the Add to list menu on a result card is a disclosure of the lists, with a field for a new one" do
    needs_solr
    id = first_ids(1).first
    list = make_list("Skulls")
    make_list("Cellos")
    list.list_items.create!(document_id: id)

    get "/catalog", params: { q: "skull", any_assets: "1" }

    assert_select ".result-card" do
      assert_select ".list-menu[data-controller=list-menu]" do
        assert_select "button.list-menu__button[type=button][aria-expanded=false][aria-controls]" do
          assert_select ".visually-hidden", text: /\A: /
        end
        assert_select ".list-menu__panel" do
          assert_select "label", text: "New list name"
          assert_select "input[name='list[name]'][maxlength='#{List::NAME_LIMIT}']"
          assert_select "button[formaction='/lists/#{list.id}/items/#{list.list_items.first.id}'][name=_method][value=delete]", text: /Remove from Skulls/
          assert_select "button[formaction='/lists/#{List.find_by(name: 'Cellos').id}/items']", text: /Add to Cellos/
        end
      end
    end
    assert_select ".result-card .toggle-bookmark-label", minimum: 1, message: "Save is still there"
  end

  test "the record page has the Add to list menu beside Save" do
    needs_solr
    get "/catalog/#{first_ids(1).first}"

    assert_select ".record-summary__save .save-control"
    assert_select ".record-summary__save .list-menu button.list-menu__button"
  end
end
