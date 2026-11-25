# frozen_string_literal: true

class CollectionStories
  # One story page of a University collection's website, read for its card and its candidate accession numbers. The sites are
  # Squiz Matrix pages: og:title, og:image and og:description in the head, the story in an .article with an h1 and paragraphs.
  # Only the article (and og:image) is read for numbers, so the header, footer and phone numbers are not.
  Page = Data.define(:url, :title, :image_url, :summary, :candidates) do
    self::SUMMARY_LENGTH = 200
    self::MIN_PARAGRAPH = 40 # a shorter first paragraph is a heading or a repeated title, not a summary

    def self.parse(html, url:)
      doc = Nokogiri::HTML(html.to_s)
      og = ->(name) { doc.at_css("meta[property='og:#{name}']")&.[]("content").to_s.squish.presence }
      article = doc.at_css(".article") || doc.at_css("main") || doc.at_css("body") || doc
      title = og.call("title") || article.at_css("h1")&.text.to_s.squish
      image_url = absolute(url, og.call("image"))

      new(url: url, title: title, image_url: image_url, summary: summary(og.call("description"), title, article),
          candidates: candidates(image_url, article, url))
    end

    def self.summary(description, title, article)
      text = description unless description.nil? || description.casecmp?(title)
      text ||= article.css("p").map { |p| p.text.squish }.find { |p| p.length >= self::MIN_PARAGRAPH && !p.casecmp?(title) }
      trim(text.to_s)
    end

    def self.trim(text)
      return text if text.length <= self::SUMMARY_LENGTH

      "#{text[0, self::SUMMARY_LENGTH].sub(/\s+\S*\z/, '').sub(/[\s,;:.–-]+\z/, '')}…"
    end

    def self.candidates(image_url, article, url)
      files = [ image_url, *article.css("img").map { |img| absolute(url, img["src"]) } ].compact
      (files.flat_map { |file| Candidates.from_file_name(file) } + Candidates.from_text(text(article))).uniq
    end

    # The article's words and its images' alt text (some captions are only there), with a space between every piece:
    # "2017/23/2/2</p><p>In Nomine" must not run together into "2/2In"
    def self.text(article)
      (article.xpath(".//text()[not(ancestor::script) and not(ancestor::style)]").map(&:text) + article.css("img[alt]").map { |img| img["alt"] }).join(" ").squish
    end

    def self.absolute(base, href)
      return if href.blank?

      URI.join(base, href.strip).to_s
    rescue URI::Error
      nil
    end
  end
end
