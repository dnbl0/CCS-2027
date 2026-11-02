require "test_helper"

# Who a record's enquiries go to (CCS-47): by the record's collection
class CollectionContactTest < ActiveSupport::TestCase
  test "the Medical History Museum and the Dental Museum use mhm.info, the Anatomy museum MDHS-museum" do
    assert_equal "mhm.info@unimelb.edu.au", CollectionContact.for("Medical History Museum").address
    assert_equal "mhm.info@unimelb.edu.au", CollectionContact.for("Henry Forman Atkinson Dental Museum").address
    assert_equal "MDHS-museum@unimelb.edu.au", CollectionContact.for("Harry Brookes Allen Museum of Anatomy and Pathology").address
  end

  test "the University Art Collection and the Grainger Museum use the Smartsheet form" do
    [ "University Art Collection", "Grainger Museum Collection" ].each do |name|
      contact = CollectionContact.for(name)
      assert contact.form?, name
      assert_match(%r{\Ahttps://app\.smartsheet\.com/b/form/}, contact.url)
    end
  end

  test "a collection with no contact, or none, gives nil" do
    assert_nil CollectionContact.for("Somewhere Else")
    assert_nil CollectionContact.for(nil)
  end
end
