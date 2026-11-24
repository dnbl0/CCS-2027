# frozen_string_literal: true

module NexusCcs
  # The home page's "Look closer" band (after Google Arts & Culture's "Guess the artwork from the pieces", the MosaicDetailsInsetFullBleed
  # section, looked at 2026-11-24): a full-width band in a pale tint of the picture's own colour, filled edge to edge with square close-ups
  # of one record's picture in columns (wide, narrow, the text panel in the middle), running off both sides; the panel asks for a guess and
  # links to the record. HomeLookCloser gives the record and its close-ups (its busiest parts).
  #
  # Every close-up is the one picture (one download, loaded lazily) placed inside its square so the square shows its part; the larger
  # close-ups go in the larger squares. They are decoration (hidden from assistive technology, out of the tab order): the panel's link is
  # the way to the record. Pointing at a close-up eases it a little closer, as Google's do.
  class LookCloserComponent < ViewComponent::Base
    # The band's columns, left to right; the text panel's is in the middle. Sizes are shares of the band's height (components/look_closer.css).
    COLUMNS = %i[narrow wide narrow text narrow wide narrow].freeze
    # The squares in each kind of column, as their sizes (for giving the larger close-ups the larger squares)
    SQUARES = { narrow: [ 0.5, 0.5 ], wide: [ 0.572, 0.286, 0.286, 0.428, 0.428 ], text: [ 0.428, 0.428 ] }.freeze

    def initialize(pick:)
      @pick = pick
    end

    attr_reader :pick

    def render? = pick.present? && pick.crops.size >= squares.size

    # Every square on the band, as [column index, place in it, size], in order
    def squares
      @squares ||= COLUMNS.each_with_index.flat_map { |kind, column| SQUARES.fetch(kind).each_with_index.map { |size, place| [ column, place, size ] } }
    end

    # The close-up for each square ([column, place] => crop): the largest close-ups in the largest squares
    def crop_for
      @crop_for ||= begin
        ordered = squares.each_with_index.sort_by { |(_, _, size), index| [ -size, index ] }.map(&:first)
        crops = pick.crops.sort_by { |crop| -crop.size }
        ordered.each_with_index.to_h { |(column, place, _), index| [ [ column, place ], crops[index] ] }
      end
    end

    def piece_style(crop) = "--x: #{crop.x}; --y: #{crop.y}; --s: #{crop.size}; --a: #{crop.aspect}"

    def band_style = pick.tint ? "--band: #{pick.tint}" : nil
  end
end
