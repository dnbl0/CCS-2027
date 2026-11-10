# frozen_string_literal: true

# Width and height of a record's image, read from the file's header, so the page can give the <img> its size: the browser then
# holds the space before the image arrives and nothing below it moves (Cumulative Layout Shift, CCS-71). Only JPEG and PNG files
# under public/ are read; anything else (a file that is not there, an address on another host) gives nil and the <img> has no size.
module ImageDimensions
  SIZES = Concurrent::Map.new
  SOF_MARKERS = [ *0xC0..0xC3, *0xC5..0xC7, *0xC9..0xCB, *0xCD..0xCF ].freeze

  module_function

  # [width, height] or nil for a path such as "/digital-assets/large/x.jpg" (a "?v=" token on it is ignored). The size is read
  # again when the file's modified time or size changes: a replaced image (an orientation fix) can have swapped its sides (CCS-425).
  def for_path(path, root: Rails.public_path)
    return unless path.is_a?(String) && path.start_with?("/") && !path.include?("..")

    file = root.join(path.split("?", 2).first.delete_prefix("/"))
    stamp = stamp(file) or return # a file not there yet is looked for again next time
    cached_stamp, size = SIZES[file.to_s]
    return size if cached_stamp == stamp && size

    size = read(file)
    SIZES[file.to_s] = [ stamp, size ] if size
    size
  end

  def stamp(file)
    stat = File.stat(file)
    [ stat.mtime.to_f, stat.size ] if stat.file?
  rescue SystemCallError
    nil
  end

  def read(file)
    return unless File.file?(file)

    File.open(file, "rb") do |io|
      head = io.read(8).to_s
      if head.start_with?("\x89PNG".b) then png(io)
      elsif head.start_with?("\xFF\xD8".b) then jpeg(io)
      end
    end
  rescue SystemCallError, EOFError
    nil
  end

  def png(io)
    io.seek(16)
    dims = io.read(8)&.unpack("NN")
    dims if dims&.all?(&:positive?)
  end

  # Walks the JPEG's segments to the first start-of-frame, which holds the size
  def jpeg(io)
    io.seek(2)
    loop do
      marker, type, length = io.read(4)&.unpack("CCn")
      return unless marker == 0xFF

      if SOF_MARKERS.include?(type)
        _precision, height, width = io.read(5)&.unpack("Cnn")
        return width&.positive? && height&.positive? ? [ width, height ] : nil
      end
      io.seek(length - 2, IO::SEEK_CUR)
    end
  end
end
