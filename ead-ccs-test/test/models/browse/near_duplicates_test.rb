require "test_helper"

class Browse::NearDuplicatesTest < ActiveSupport::TestCase
  test "one value of each spelling, the first (most records) kept" do
    pairs = [ [ "Greater London", 9 ], [ "London", 8 ], [ "Île-de-France", 5 ], [ "Ile de France", 2 ], [ "Book", 4 ], [ "book", 1 ] ]
    assert_equal [ "Greater London", "Île-de-France", "Book" ], Browse::NearDuplicates.reject(pairs).map(&:first)
  end

  test "not the page itself, not its region, and no subject that only names a place already shown" do
    places = Browse::NearDuplicates.reject([ [ "Europe", 9 ], [ "Western Europe", 5 ], [ "France", 4 ], [ "Paris", 3 ] ], shown: [ "France" ], region: "Europe")
    assert_equal [ "Paris" ], places.map(&:first)
    subjects = Browse::NearDuplicates.reject([ [ "France, Paris", 7 ], [ "France, Etaples", 3 ], [ "Travel", 2 ] ], shown: [ "France", "Paris" ])
    assert_equal [ "France, Etaples", "Travel" ], subjects.map(&:first)
  end

  test "an entity (anything with a name) is matched by its name" do
    entry = Struct.new(:name)
    assert_equal 1, Browse::NearDuplicates.reject([ [ entry.new("Bunny, Rupert"), 3 ], [ entry.new("BUNNY Rupert"), 1 ] ]).size
  end
end
