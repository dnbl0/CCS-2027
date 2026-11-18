# frozen_string_literal: true

# What the category, collection, theme and story pages share (docs/categories-themes-stories.md): their breadcrumb trail and search
# metadata (Browse::Meta, drawn by PageMeta and HeaderComponent as for the browse pages), and a plain 503 when the index cannot answer.
module DiscoveryPage
  extend ActiveSupport::Concern

  included do
    layout "pages"
  end

  private

  # trail: [[label, path or nil], ...], the last one this page; keep: the query parameters that make a different page
  def use_meta(name, description, trail, keep: [], thin: false)
    @browse_meta = Browse::Meta.new(name, description, thin, nil, keep, trail[0...-1].map { |label, path| [ label, path ] })
    @browse_trail = trail
  end

  def not_found! = raise(ActionController::RoutingError, "Not Found")

  def unavailable!
    response.headers["Retry-After"] = "300"
    render "discovery_pages/unavailable", status: :service_unavailable
  end
end
