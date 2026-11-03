# frozen_string_literal: true

module Browse
  # What a browse page tells search engines (PageMeta draws it): the meta description, whether to ask for it not to be indexed,
  # which query parameters belong in the canonical address, and the JSON-LD. Conservative on purpose: names, counts and links
  # only, never an image, a record's title or anything of a withheld record.
  #
  #   description   one sentence
  #   thin          a page too small to be worth indexing (fewer than MIN_INDEXED_RECORDS records)
  #   about         the thing the page is about, as a schema.org hash without @context, or nil
  #   keep_params   the query parameters that make a different page (the letter of a hub, the page of records)
  Meta = Data.define(:name, :description, :thin, :about, :keep_params, :parents) do
    def self.hub(kind)
      new(kind.plural, I18n.t("browse.kinds.#{kind.key}.hub_description"), false, nil, %w[letter page], [ [ I18n.t("browse.title"), "/browse" ] ])
    end

    def self.overview = new(I18n.t("browse.title"), I18n.t("browse.description"), false, nil, [], [])

    def self.time = new(I18n.t("browse.time.title"), I18n.t("browse.time.description"), false, nil, [], [ [ I18n.t("browse.title"), "/browse" ] ])

    def self.entity(entry, result)
      span = span_of(result)
      description = I18n.t(span ? "browse.entity.description_dates" : "browse.entity.description", count: ActiveSupport::NumberHelper.number_to_delimited(result.total), name: entry.name, span: span)
      new(entry.name, description, result.total < MIN_INDEXED_RECORDS, about_entity(entry, result), %w[page],
          [ [ I18n.t("browse.title"), "/browse" ], [ entry.kind.plural, "/browse/#{entry.kind.key}" ] ])
    end

    def self.period(period, total)
      new(period.label, I18n.t("browse.period.description", count: ActiveSupport::NumberHelper.number_to_delimited(total), span: period.span), total < MIN_INDEXED_RECORDS,
          { "@type" => "DefinedTerm", "name" => period.label }, %w[page],
          [ [ I18n.t("browse.title"), "/browse" ], [ I18n.t("browse.time.plural"), "/browse/time" ] ])
    end

    def self.span_of(result)
      return unless result.first_year && result.last_year

      from = Browse.year(result.first_year)
      to = Browse.year(result.last_year)
      from == to ? from : "#{from} to #{to}"
    end

    # Person only when the records show life dates ("Name (1882 – 1961) Role"); an organisation or a maker of unknown kind is a
    # plain Thing, so a company is never called a person.
    def self.about_entity(entry, result)
      type = entry.kind.schema_type
      type = "Thing" if type == "Person" && !result.documents.any? { |document| Meta.life_dates(document, entry.variants) }
      { "@type" => type, "name" => entry.name }
    end

    # "8 July 1882 – 20 February 1961" from a record's creator_display_ssim for one of the creator's spellings, or nil
    def self.life_dates(document, names)
      Array(document["creator_display_ssim"]).each do |display|
        names.each do |name|
          dates = display.to_s[/\A#{Regexp.escape(name)} \(([^)]*\d{3,4}[^)]*)\)/, 1]
          return dates if dates && !dates.match?(/estab/i)
        end
      end
      nil
    end

    def thin? = thin

    def json_ld(base_url, url)
      page = { "@context" => "https://schema.org", "@type" => "CollectionPage", "name" => name, "url" => url, "description" => description,
               "isPartOf" => { "@type" => "WebSite", "name" => StructuredData::SITE_NAME, "url" => "#{base_url}/" },
               "publisher" => StructuredData::PUBLISHER }
      if about
        page["about"] = about
        page["about"] = about.merge("inDefinedTermSet" => "#{base_url}#{parents.last.last}") if about["@type"] == "DefinedTerm" && parents.any?
      end
      page["breadcrumb"] = breadcrumb(base_url, url)
      [ page ]
    end

    private

    def breadcrumb(base_url, url)
      items = parents.map { |label, path| [ label, "#{base_url}#{path}" ] } << [ name, url ]
      { "@type" => "BreadcrumbList",
        "itemListElement" => items.each_with_index.map { |(label, href), index| { "@type" => "ListItem", "position" => index + 1, "name" => label, "item" => href } } }
    end
  end
end
