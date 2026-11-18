# frozen_string_literal: true

module NexusCcs
  # The "Place" filter (place_hierarchy_ssim, written by rake geo:write): Region > Country > State > Place as nested lists. Each
  # level is Blacklight's own facet item (a link that adds the filter, its count; a chosen one shows its remove control), and a
  # level's children sit in a native disclosure, open along the chosen branch. Not shown while the field has no values (ListComponent).
  # An addition beside the workbook's Region filter (#14), not a workbook filter (docs/time-and-place.md).
  class PlaceHierarchyFacetComponent < Blacklight::Facets::ListComponent
    Node = Struct.new(:item, :children)

    def roots
      nodes = @facet_field.paginator.items.to_h { |item| [ item.value.to_s, Node.new(item, []) ] }
      roots = []
      nodes.each do |path, node|
        parent = nodes[Geo::Hierarchy.parent(path).to_s]
        if parent then parent.children << node
        elsif Geo::Hierarchy.depth(path) == 1 then roots << node
        end
      end
      sort(roots)
    end

    def sort(nodes) = nodes.sort_by { |node| [ -node.item.hits.to_i, node.item.value.to_s ] }

    def item(node) = render(Blacklight::Facets::ItemComponent.new(facet_item: facet_item_presenter(node.item), wrapping_element: nil))

    def open?(node)
      path = node.item.value.to_s
      chosen.any? { |value| value.start_with?("#{path}#{Geo::Hierarchy::SEPARATOR}") }
    end

    # A region's countries are always drawn; the levels under a country only once it or a place in it is chosen (a drill-down),
    # so a results page draws a few hundred filter links rather than every state and town (docs/time-and-place.md)
    def children_shown?(node)
      return false if node.children.empty?

      Geo::Hierarchy.depth(node.item.value) == 1 || chosen.include?(node.item.value.to_s) || open?(node)
    end

    def chosen = @chosen ||= Array(helpers.search_state.filter(facet_config.key).values).map(&:to_s)

    def label(node) = Geo::Hierarchy.label(node.item.value)
  end
end
