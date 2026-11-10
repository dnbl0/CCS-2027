# frozen_string_literal: true

# How to contact the team of a record's collection (CCS-47, confirmed in Product Group on 2 July): the Medical History
# Museum, the Dental Museum and the Anatomy museum have an email address; the University Art Collection and the Grainger
# Museum Collection use Museums & Collections' Smartsheet form. Keyed by the record's collection (collection_ssim).
# The Help page's Contact us section lists the same contacts (app/views/pages/help.html.erb).
class CollectionContact
  ACCESS_REQUEST_FORM = "https://app.smartsheet.com/b/form/209fed78a83f400e80d0836d6fb517c4"

  CONTACTS = {
    "Medical History Museum" => { address: "mhm.info@unimelb.edu.au" },
    "Henry Forman Atkinson Dental Museum" => { address: "mhm.info@unimelb.edu.au" },
    "Harry Brookes Allen Museum of Anatomy and Pathology" => { address: "MDHS-museum@unimelb.edu.au" },
    "University Art Collection" => { url: ACCESS_REQUEST_FORM },
    "Grainger Museum Collection" => { url: ACCESS_REQUEST_FORM }
  }.freeze

  attr_reader :collection, :address, :url

  def self.for(collection)
    attributes = CONTACTS[collection.to_s]
    new(collection, **attributes) if attributes
  end

  def initialize(collection, address: nil, url: nil)
    @collection = collection
    @address = address
    @url = url
  end

  def email? = address.present?
  def form? = url.present?
end
