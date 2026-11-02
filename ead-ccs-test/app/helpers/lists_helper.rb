# frozen_string_literal: true

# The visitor's named lists (CCS-389) as the pages draw them: the "Add to list" menu on every result card, the lists
# page's icon actions. Reads the guest user from the session cookie and never creates it (see GuestLists).
module ListsHelper
  # Bootstrap Icons (16px grid), drawn in the current text colour; delete is the search history's
  LIST_ICONS = {
    add: "M8 2a.5.5 0 0 1 .5.5v5h5a.5.5 0 0 1 0 1h-5v5a.5.5 0 0 1-1 0v-5h-5a.5.5 0 0 1 0-1h5v-5A.5.5 0 0 1 8 2",
    check: "M12.736 3.97a.733.733 0 0 1 1.047 0c.286.289.29.756.01 1.05L7.88 12.01a.733.733 0 0 1-1.065.02L3.217 8.384a.76.76 0 0 1 0-1.06.733.733 0 0 1 1.047 0l3.052 3.093 5.4-6.425z",
    rename: "M12.146.146a.5.5 0 0 1 .708 0l3 3a.5.5 0 0 1 0 .708l-10 10a.5.5 0 0 1-.168.11l-5 2a.5.5 0 0 1-.65-.65l2-5a.5.5 0 0 1 .11-.168zM11.207 2.5 13.5 4.793 14.793 3.5 12.5 1.207zm1.586 3L10.5 3.207 4 9.707V10h.5a.5.5 0 0 1 .5.5v.5h.5a.5.5 0 0 1 .5.5v.5h.293zm-9.761 5.175-.106.106-1.528 3.821 3.821-1.528.106-.106A.5.5 0 0 1 5 12.5V12h-.5a.5.5 0 0 1-.5-.5V11h-.5a.5.5 0 0 1-.468-.325z",
    delete: SearchHistoryHelper::ACTION_ICONS.fetch(:delete)
  }.freeze

  # The visitor's lists, alphabetical; one query per request
  def menu_lists
    @menu_lists ||= begin
      id = session[:blacklight_guest_user_id]
      id ? List.where(user_id: id).by_name.to_a : []
    end
  end

  # The list item of this record in this list, or nil: one query per request for every record on the page
  def list_item_for(list, document_id)
    @list_item_ids ||= ListItem.where(list_id: menu_lists.map(&:id)).pluck(:list_id, :document_id, :id)
                               .to_h { |list_id, doc_id, id| [ [ list_id, doc_id ], id ] }
    @list_item_ids[[ list.id, document_id.to_s ]]
  end

  # A decorative icon: the button's own text gives the name
  def list_icon(name, css_class: "history-action__icon")
    tag.svg(tag.path(d: LIST_ICONS.fetch(name)), class: css_class, viewBox: "0 0 16 16", width: 16, height: 16,
            fill: "currentColor", aria: { hidden: true }, focusable: "false")
  end

  # An icon-only action's content on the lists page: the icon, and its name as visually hidden text ("Rename list: Violins")
  def list_action_content(name, list_name)
    safe_join([ list_icon(name), tag.span(t("nexus_ccs.lists.actions.#{name}_named", name: list_name), class: "visually-hidden") ])
  end
end
