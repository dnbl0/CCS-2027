# frozen_string_literal: true

require "zlib"

module Colour
  # Reads the pixels of a small PNG, in plain Ruby (zlib is in the standard library). The bundle has no image library
  # (image_processing 2.2 is there without ruby-vips or mini_magick), and adding one means a native library on every machine
  # and CI runner. The DAM converts an image to a small PNG itself (Colour::Fetcher asks for /png/ at 64 pixels wide), so
  # only a few thousand pixels are read per record, which plain Ruby does in milliseconds.
  #
  # Supports 8-bit greyscale, grey with alpha, RGB, RGBA and palette images, not interlaced: what the DAM sends. Anything else
  # raises Colour::Png::Unsupported.
  class Png
    class Unsupported < StandardError; end

    SIGNATURE = "\x89PNG\r\n\x1A\n".b
    CHANNELS = { 0 => 1, 2 => 3, 3 => 1, 4 => 2, 6 => 4 }.freeze
    MAX_PIXELS = 1_000_000

    def self.png?(bytes) = bytes.to_s.b.start_with?(SIGNATURE)

    # Returns [ [ r, g, b ], ... ] for the pixels that are not (mostly) transparent
    def self.pixels(bytes) = new(bytes).pixels

    # The image's size, once #pixels has read it (HomeLookCloser reads the pixels as a grid)
    attr_reader :width, :height

    def initialize(bytes)
      @bytes = bytes.to_s.b
      raise Unsupported, "not a PNG" unless self.class.png?(@bytes)
    end

    def pixels
      read_chunks
      rows = unfilter(Zlib::Inflate.inflate(@data))
      rows.flat_map { |row| row_pixels(row) }.compact
    rescue Zlib::Error => e
      raise Unsupported, "damaged PNG (#{e.message})"
    end

    private

    def read_chunks
      offset = 8
      @data = +"".b
      while offset + 8 <= @bytes.bytesize
        length, type = @bytes.byteslice(offset, 8).unpack("Na4")
        body = @bytes.byteslice(offset + 8, length)
        case type
        when "IHDR" then header(body)
        when "PLTE" then @palette = body.unpack("C*").each_slice(3).to_a
        when "tRNS" then @transparency = body.unpack("C*")
        when "IDAT" then @data << body
        when "IEND" then break
        end
        offset += 12 + length
      end
      raise Unsupported, "no image header" unless @width
    end

    def header(body)
      @width, @height, depth, @colour_type, _compression, _filter, interlace = body.unpack("NNCCCCC")
      raise Unsupported, "#{depth}-bit PNG" unless depth == 8
      raise Unsupported, "interlaced PNG" unless interlace.zero?
      raise Unsupported, "colour type #{@colour_type}" unless CHANNELS.key?(@colour_type)
      raise Unsupported, "image too large" if @width * @height > MAX_PIXELS

      @channels = CHANNELS.fetch(@colour_type)
    end

    # PNG's five row filters (None, Sub, Up, Average, Paeth), undone row by row
    def unfilter(raw)
      stride = @width * @channels
      previous = Array.new(stride, 0)
      Array.new(@height) do |y|
        start = y * (stride + 1)
        filter = raw.getbyte(start)
        row = raw.byteslice(start + 1, stride).unpack("C*")
        raise Unsupported, "short image data" if row.size < stride

        stride.times do |i|
          left = i >= @channels ? row[i - @channels] : 0
          up = previous[i]
          corner = i >= @channels ? previous[i - @channels] : 0
          row[i] = (row[i] + predictor(filter, left, up, corner)) & 0xFF
        end
        previous = row
      end
    end

    def predictor(filter, left, up, corner)
      case filter
      when 0 then 0
      when 1 then left
      when 2 then up
      when 3 then (left + up) / 2
      when 4 then paeth(left, up, corner)
      else raise Unsupported, "unknown row filter #{filter}"
      end
    end

    def paeth(left, up, corner)
      estimate = left + up - corner
      distances = [ (estimate - left).abs, (estimate - up).abs, (estimate - corner).abs ]
      return left if distances[0] <= distances[1] && distances[0] <= distances[2]

      distances[1] <= distances[2] ? up : corner
    end

    def row_pixels(row)
      row.each_slice(@channels).map do |values|
        case @colour_type
        when 0 then [ values[0] ] * 3
        when 4 then values[1] < 128 ? nil : [ values[0] ] * 3
        when 2 then values
        when 6 then values[3] < 128 ? nil : values.first(3)
        when 3 then palette_pixel(values[0])
        end
      end
    end

    def palette_pixel(index)
      raise Unsupported, "palette image without a palette" unless @palette
      return nil if @transparency && @transparency[index].to_i < 128 && index < @transparency.size

      @palette.fetch(index) { raise Unsupported, "palette index out of range" }
    end
  end
end
