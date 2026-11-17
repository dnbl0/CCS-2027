# frozen_string_literal: true

module Colour
  # The dominant colours of an image, their names, and a small colour histogram (for "Looks similar").
  #
  # How: every pixel is put in one of 512 boxes (8 levels of red, green and blue); boxes whose average colours are close are
  # merged, biggest first; the merged groups that cover at least 5% of the picture are its palette (at most 5, biggest first).
  # Each palette colour gets one of the twelve names in NAMES (Colour::Palette.name_for), and a record's colour names are those
  # covering at least 10% of the picture. Deterministic: the same image always gives the same answer.
  class Palette
    NAMES = %w[red orange yellow green teal blue purple pink brown black grey white].freeze
    MAX_COLOURS = 5
    MIN_SHARE = 0.05
    NAME_SHARE = 0.10
    MERGE_DISTANCE = 56 # how close (RGB distance) two boxes' average colours must be to count as one colour

    Swatch = Data.define(:hex, :share, :name)

    attr_reader :swatches

    # pixels: [ [ r, g, b ], ... ]
    def initialize(pixels)
      raise ArgumentError, "no pixels" if pixels.empty?

      @pixels = pixels
      @swatches = dominant
    end

    # The palette's colour names, biggest share first (at least the biggest colour's)
    def names
      shares = swatches.each_with_object(Hash.new(0.0)) { |swatch, sum| sum[swatch.name] += swatch.share }
      ranked = shares.sort_by { |name, share| [ -share, NAMES.index(name) ] }
      ranked.select { |_name, share| share >= NAME_SHARE }.map(&:first).presence || [ ranked.first.first ]
    end

    def hexes = swatches.map(&:hex)

    def to_h = { "palette" => swatches.map { |swatch| { "hex" => swatch.hex, "share" => swatch.share, "name" => swatch.name } }, "buckets" => names, "histogram" => histogram }

    # 64 boxes (4 levels of each of red, green and blue): { "box" => share }, only the boxes the picture uses
    def histogram
      counts = @pixels.each_with_object(Hash.new(0)) { |(r, g, b), sum| sum[((r >> 6) << 4) | ((g >> 6) << 2) | (b >> 6)] += 1 }
      counts.sort.to_h { |box, count| [ box.to_s, (count.to_f / @pixels.size).round(4) ] }
    end

    # One of NAMES for a colour, from its hue, saturation and lightness
    def self.name_for(rgb)
      hue, saturation, lightness = hsl(*rgb)
      return "black" if lightness < 0.13
      return "white" if lightness > 0.9 || (lightness > 0.82 && saturation < 0.6)
      return lightness < 0.2 ? "black" : "grey" if saturation < 0.12 || (saturation < 0.2 && lightness > 0.3)

      hue_name(hue, saturation, lightness)
    end

    def self.hue_name(hue, saturation, lightness)
      case hue
      when 0...15, 345..360 then lightness > 0.72 ? "pink" : (lightness < 0.3 && saturation < 0.6 ? "brown" : "red")
      when 15...45 then lightness < 0.45 || (saturation < 0.45 && lightness < 0.7) ? "brown" : "orange"
      when 45...70 then lightness < 0.3 ? "brown" : "yellow"
      when 70...165 then "green"
      when 165...200 then "teal"
      when 200...255 then "blue"
      when 255...290 then "purple"
      else lightness < 0.3 ? "purple" : "pink"
      end
    end

    # Hue in degrees (0-360), saturation and lightness (0-1)
    def self.hsl(red, green, blue)
      r, g, b = [ red, green, blue ].map { |value| value / 255.0 }
      max, min = [ r, g, b ].minmax.reverse
      lightness = (max + min) / 2
      return [ 0.0, 0.0, lightness ] if max == min

      delta = max - min
      saturation = lightness > 0.5 ? delta / (2 - max - min) : delta / (max + min)
      hue = case max
      when r then ((g - b) / delta) % 6
      when g then ((b - r) / delta) + 2
      else ((r - g) / delta) + 4
      end
      [ hue * 60, saturation, lightness ]
    end

    def self.hex(rgb) = format("#%02x%02x%02x", *rgb.map { |value| value.round.clamp(0, 255) })

    private

    def dominant
      groups = []
      boxes.sort_by { |key, box| [ -box[0], key ] }.each do |_key, (count, *sums)|
        colour = sums.map { |sum| sum.to_f / count }
        group = groups.find { |candidate| distance(candidate[:colour], colour) < MERGE_DISTANCE }
        next groups << { count: count, sums: sums.dup, colour: colour } unless group

        group[:count] += count
        group[:sums] = group[:sums].zip(sums).map(&:sum)
        group[:colour] = group[:sums].map { |sum| sum.to_f / group[:count] }
      end
      kept = groups.sort_by { |group| -group[:count] }.select { |group| group[:count].to_f / @pixels.size >= MIN_SHARE }.first(MAX_COLOURS)
      kept = [ groups.max_by { |group| group[:count] } ] if kept.empty?
      kept.map do |group|
        Swatch.new(hex: self.class.hex(group[:colour]), share: (group[:count].to_f / @pixels.size).round(3), name: self.class.name_for(group[:colour]))
      end
    end

    # { box => [ count, sum of red, sum of green, sum of blue ] }
    def boxes
      @pixels.each_with_object({}) do |(r, g, b), result|
        box = (result[((r >> 5) << 6) | ((g >> 5) << 3) | (b >> 5)] ||= [ 0, 0, 0, 0 ])
        box[0] += 1
        box[1] += r
        box[2] += g
        box[3] += b
      end
    end

    def distance(one, other) = Math.sqrt(one.zip(other).sum { |a, b| (a - b)**2 })
  end
end
