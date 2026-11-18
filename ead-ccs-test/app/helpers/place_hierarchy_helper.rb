# frozen_string_literal: true

# The Place filter's values are paths ("Oceania|Australia|Victoria"): a value, and a chosen value's pill, are shown by the last
# level ("Victoria"); the tree around it in the sidebar says where it sits
module PlaceHierarchyHelper
  def place_hierarchy_facet_label(value) = Geo::Hierarchy.label(value)
end
