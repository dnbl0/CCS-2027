# frozen_string_literal: true

# The head tags for search engines and social networks (layouts/_seo_head). The same header goes out as X-Robots-Tag (BotGuard
# reads request.env["ccs.robots"]), so a record page that is withheld from search says so in both places.
module SeoHelper
  def page_meta
    @page_meta ||= PageMeta.new(
      controller: controller_path, action: action_name, path: request.path, params: request.query_parameters,
      base_url: BotControls.base_url(request), title: plain_text(content_for(:title).presence || @page_title), document: @document
    ).tap { |meta| request.env["ccs.robots"] = meta.robots }
  end

  # A JSON-LD data block. The JSON is escaped for HTML (StructuredData.to_json_ld), so it is safe to write as it is.
  def json_ld_tag(data) = tag.script(StructuredData.to_json_ld(data).html_safe, type: "application/ld+json") # rubocop:disable Rails/OutputSafety

  private

  # A page title as plain text: Blacklight hands the record page's title over as HTML, which a meta tag's content must not be
  def plain_text(title) = CGI.unescapeHTML(strip_tags(title.to_s)).squish
end
