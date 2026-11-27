# frozen_string_literal: true

# Themed collections (config/themes.yml, docs/categories-themes-stories.md): a title, an introduction and a Blacklight search
# (facet filters and an optional date range). A theme's page shows its highlights (Showcase) and opens the full list as the search page.
# Wording in the file is placeholder until the collections team approves it.
module Themes
  CONFIG_PATH = Rails.root.join("config/themes.yml")
  SLUG = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  FIELD = /\A[a-z_]+_(ssim|ssi|isi|bsi)\z/
  DATE_FIELD = ExploreEntryPoints::DATE_FIELD

  Theme = Data.define(:slug, :title, :intro, :filters, :range, :hero) do
    def path = Rails.application.routes.url_helpers.theme_path(slug)

    # The theme's records on the search page (the any_assets marker keeps the default "With a digital asset" filter off, docs/adr/0004)
    def search_query
      query = { any_assets: "1", search_field: "all_fields", f: filters }
      range ? query.merge(range: { DATE_FIELD => { begin: range["begin"], end: range["end"] } }) : query
    end

    # The same records as Solr filters; values are from the file and quoted (SolrQuery.phrase)
    def fq
      list = filters.map { |field, values| SolrQuery.field(field, values) }
      range ? list << "#{DATE_FIELD}:[#{range['begin'].to_i} TO #{range['end'].to_i}]" : list
    end
  end

  def self.all(path = CONFIG_PATH)
    YAML.safe_load_file(path).fetch("themes").map do |row|
      Theme.new(slug: row.fetch("slug"), title: row.fetch("title"), intro: row["intro"].to_s, filters: row.fetch("filters").transform_values { |v| Array(v).map(&:to_s) },
                range: row["range"], hero: row["hero"]&.to_s)
    end
  end

  def self.find(slug) = all.find { |theme| theme.slug == slug.to_s }

  # Problems with the file (test/models/themes_test.rb runs it): a bad slug, a field that is not a search filter, an empty filter
  def self.problems(themes = all, facet_fields = CatalogController.blacklight_config.facet_fields.keys)
    themes.flat_map do |theme|
      list = []
      list << "#{theme.slug}: bad slug" unless theme.slug.match?(SLUG)
      list << "#{theme.slug}: no filters" if theme.filters.empty?
      theme.filters.each_key { |field| list << "#{theme.slug}: #{field} is not a search filter" unless field.match?(FIELD) && facet_fields.include?(field) }
      list
    end + themes.map(&:slug).tally.select { |_, n| n > 1 }.keys.map { |slug| "#{slug}: used twice" }
  end
end
