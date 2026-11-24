# frozen_string_literal: true

require "kramdown"

# Stories (online exhibitions, docs/categories-themes-stories.md): Markdown files in content/stories/*.md with a YAML front matter
# (title, summary, hero, author, date), drawn at /stories/<file name>. Two embeds, each alone on its line:
#
#   {{record emu_mc-20882}}                       the record as the site's record card (its picture only when it may be shown)
#   {{search "violin"}}                           four results of that search and a link to all of them
#   {{search "q=violin&f[collection_ssim][]=Grainger Museum Collection" "Violins"}}   a query string and a heading
#
# The Markdown is turned into HTML by kramdown and then sanitised (a short list of tags, links with href only), so a file cannot add
# a script, a style or an event attribute. Spotlight is not used: it needs staff sign-in, which the site does not have.
module Stories
  DIRECTORY = Rails.root.join("content/stories")
  SLUG = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  RECORD_ID = /\A[A-Za-z0-9_.:-]{1,100}\z/
  EMBED = /^[ \t]*\{\{\s*(record|search)\s+(.+?)\s*\}\}[ \t]*$/
  MARK = "CCSSTORYEMBED"
  TAGS = %w[p h2 h3 h4 ul ol li a em strong blockquote code pre hr br].freeze
  ATTRIBUTES = %w[href].freeze
  SEARCH_KEYS = %w[q f range search_field].freeze

  Story = Data.define(:slug, :title, :summary, :hero, :author, :date, :body) do
    def path = Rails.application.routes.url_helpers.story_path(slug)
    # wording the collections team has not written yet: kept out of the sitemap until it is
    def placeholder? = title.include?("(placeholder)")
    def parts = Stories.parts(body)
  end

  # An embed: kind :record (value: the id) or :search (value: the search parameters, heading: the strip's heading or nil)
  Embed = Data.define(:kind, :value, :heading)

  def self.all(directory = DIRECTORY)
    Dir[File.join(directory, "*.md")].filter_map { |file| load(file) }.sort_by { |story| [ -story.date.to_time.to_i, story.slug ] }
  end

  def self.find(slug, directory = DIRECTORY)
    return unless slug.to_s.match?(SLUG)

    file = File.join(directory, "#{slug}.md")
    load(file) if File.file?(file)
  end

  def self.load(file)
    slug = File.basename(file, ".md")
    return unless slug.match?(SLUG)

    text = File.read(file)
    match = text.match(/\A---\s*\n(.*?)\n---\s*\n(.*)\z/m)
    return unless match

    meta = YAML.safe_load(match[1], permitted_classes: [ Date ]) || {}
    Story.new(slug: slug, title: meta.fetch("title").to_s, summary: meta["summary"].to_s, hero: meta["hero"]&.to_s.presence,
              author: meta["author"].to_s.presence, date: (meta["date"].is_a?(Date) ? meta["date"] : Date.parse(meta["date"].to_s)), body: match[2])
  rescue KeyError, Date::Error, Psych::Exception => e
    Rails.logger.warn("Story #{file} skipped: #{e.class}")
    nil
  end

  # The body as [html, embed, html, embed, ...]: sanitised HTML (html_safe) and the embeds in their places
  def self.parts(markdown)
    embeds = []
    marked = markdown.gsub(EMBED) do
      embed = parse_embed(Regexp.last_match(1), Regexp.last_match(2))
      next "" unless embed

      embeds << embed
      "\n\n#{MARK}#{embeds.size - 1}\n\n"
    end
    html = sanitize(Kramdown::Document.new(marked, input: "kramdown", auto_ids: false, smart_quotes: %w[lsquo rsquo ldquo rdquo]).to_html)
    html.split(%r{<p>#{MARK}(\d+)</p>}).each_with_index.filter_map do |piece, index|
      index.odd? ? embeds[piece.to_i] : (piece.html_safe if piece.strip.present?) # rubocop:disable Rails/OutputSafety -- sanitised above
    end
  end

  def self.sanitize(html) = Rails::HTML5::SafeListSanitizer.new.sanitize(html, tags: TAGS, attributes: ATTRIBUTES)

  def self.parse_embed(kind, args)
    if kind == "record"
      Embed.new(:record, args, nil) if args.match?(RECORD_ID)
    else
      quoted = args.scan(/"([^"]*)"/).flatten
      return if quoted.empty?

      Embed.new(:search, search_params(quoted.first), quoted[1].presence)
    end
  end

  # Plain words are a keyword search; a query string keeps only the search's own parameters
  def self.search_params(text)
    params = text.include?("=") ? Rack::Utils.parse_nested_query(text).slice(*SEARCH_KEYS) : { "q" => text }
    { "search_field" => "all_fields", "any_assets" => "1" }.merge(params)
  end

  private_class_method :load, :sanitize, :parse_embed, :search_params
end
