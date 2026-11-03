# frozen_string_literal: true

# The oEmbed discovery tag (https://oembed.com, section 4): a page that can be embedded says where its oEmbed description is, so a
# CMS or chat tool given the page's address can find the iframe. The endpoint (OembedsController) answers for records and shared
# galleries, tier-safe.
module EmbedsHelper
  # page_url: the absolute address of the page being described
  def oembed_link_tag(page_url, title)
    href = "#{BotControls.base_url(request)}#{oembed_path(url: page_url, format: 'json')}"
    tag.link(rel: "alternate", type: "application/json+oembed", href: href, title: strip_tags(title.to_s))
  end
end
