# frozen_string_literal: true

# The shape of a picture for the justified rows (justified_controller.js, components/home_sections.css): its width over its height,
# held between 0.5 and 2.6 as the controller holds it, as a "--a" style for the item; nil when the size is not known (the controller
# measures the picture in the browser).
module AspectHelper
  def aspect_style(width, height)
    return nil unless width.to_f.positive? && height.to_f.positive?

    "--a: #{(width.to_f / height).clamp(0.5, 2.6).round(3)}"
  end
end
