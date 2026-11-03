# frozen_string_literal: true

require "erb"

# The iframe snippets for an embed page, and the sizes oEmbed reports. A record's card is a fixed width and a height that
# depends on whether it carries an image or a notice (the page has no script to tell its parent); a gallery's is taller, as it
# lists records. The responsive snippet fills its column up to the width, at the same height.
class EmbedCode
  PROVIDER = "Collections Navigator, University of Melbourne"
  RECORD_WIDTH = 480
  GALLERY_WIDTH = 600
  GALLERY_HEIGHT = 560

  attr_reader :src, :title, :width, :height

  # src: the absolute address of the embed page; title: names the frame for assistive technology (WCAG 4.1.2)
  def initialize(src:, title:, width:, height:)
    @src = src
    @title = title
    @width = width
    @height = height
  end

  def self.for_record(document, src:)
    heading = Array(document["title_tsim"]).first.presence || "Untitled"
    height = SharedMedia.thumbnail_path(document) ? 240 : 200
    height += 100 if SharedMedia.withheld_reason(document)
    new(src: src, title: "#{heading} - #{PROVIDER}", width: RECORD_WIDTH, height: height)
  end

  def self.for_gallery(list, src:)
    new(src: src, title: "Gallery: #{list.name} - #{PROVIDER}", width: GALLERY_WIDTH, height: GALLERY_HEIGHT)
  end

  # A frame of the stated size
  def fixed
    %(<iframe src="#{h(src)}" title="#{h(title)}" width="#{width}" height="#{height}" style="border:0;" loading="lazy"></iframe>)
  end

  # A frame that fills its column, no wider than the page it embeds
  def responsive
    %(<iframe src="#{h(src)}" title="#{h(title)}" style="width:100%;max-width:#{width}px;height:#{height}px;border:0;" loading="lazy"></iframe>)
  end

  # The size, held to a consumer's maxwidth and maxheight (oEmbed 1.0)
  def fitted(max_width: nil, max_height: nil)
    w = max_width.to_i.positive? ? [ width, max_width.to_i ].min : width
    hgt = max_height.to_i.positive? ? [ height, max_height.to_i ].min : height
    self.class.new(src: src, title: title, width: w, height: hgt)
  end

  private

  def h(text) = ERB::Util.html_escape(text)
end
