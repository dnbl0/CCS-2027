# frozen_string_literal: true

require "test_helper"

# The site owner's standing rule: pictures of cultural objects are shown whole, never cropped (docs/decisions-2027.md). Every
# component stylesheet styles object pictures, so none may use object-fit: cover. Site photographs (the home page banner) live in
# pages/ and are not object pictures.
class NoCroppedImagesTest < ActiveSupport::TestCase
  test "no component stylesheet crops a picture with object-fit: cover" do
    offenders = Rails.root.glob("app/assets/stylesheets/components/**/*.css").flat_map do |path|
      path.each_line.with_index(1).filter_map do |line, number|
        "#{path.relative_path_from(Rails.root)}:#{number}" if line.match?(/object-fit:\s*cover/) && !line.lstrip.start_with?("/*", "*")
      end
    end

    assert_empty offenders, "cultural objects are never cropped: use object-fit: contain"
  end
end
