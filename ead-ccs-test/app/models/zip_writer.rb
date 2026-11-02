# frozen_string_literal: true

require "zlib"

# Writes a ZIP archive to an IO, with the Ruby standard library only (Zlib's CRC-32): no gem is needed for the bulk download
# (CCS-167). Entries are STORED, not compressed: the digital assets are JPEG, MP4 and PDF files, which do not compress, and
# it keeps the writer small. Not ZIP64, so an entry or the archive over 4 GiB, or more than 65,535 entries, is refused
# (BulkDownload's limits are far below that). A file is read twice (the CRC goes in front of its data), never held whole.
#
# Entry names are checked, not trusted: relative, forward slashes, no empty or ".." part, no control characters, no
# duplicates. (A name that fails raises Error; BulkDownload builds names from sanitised parts and never fails this.)
#
#   ZipWriter.write(io) { |zip| zip.add_data("manifest.csv", csv); zip.add_file("a/b.jpg", "/path/b.jpg") }
class ZipWriter
  class Error < StandardError; end

  MAX_ENTRIES = 65_535
  MAX_SIZE = 0xFFFF_FFFF
  CHUNK = 1.megabyte
  UTF8_NAMES = 0x0800 # general purpose bit 11: names are UTF-8

  def self.write(io)
    writer = new(io)
    yield writer
    writer.finish
  end

  def initialize(io)
    @io = io
    @io.binmode if @io.respond_to?(:binmode)
    @entries = []
    @names = {}
    @offset = 0
  end

  def add_data(name, data, time: Time.now)
    data = data.b
    add_entry(name, data.bytesize, Zlib.crc32(data), time) { |io| io.write(data) }
  end

  def add_file(name, path, time: nil)
    size = File.size(path)
    crc = 0
    File.open(path, "rb") do |file|
      while (chunk = file.read(CHUNK))
        crc = Zlib.crc32(chunk, crc)
      end
    end
    add_entry(name, size, crc, time || File.mtime(path)) do |io|
      File.open(path, "rb") { |file| IO.copy_stream(file, io) }
    end
  end

  # Writes the central directory; the archive is complete after this
  def finish
    directory_start = @offset
    @entries.each { |entry| put(central_header(entry)) }
    put([ 0x06054b50, 0, 0, @entries.size, @entries.size, @offset - directory_start, directory_start, 0 ].pack("VvvvvVVv"))
    @io.flush
  end

  private

  Entry = Struct.new(:name, :size, :crc, :dos_time, :dos_date, :offset)

  def add_entry(name, size, crc, time)
    name = check_name(name)
    raise Error, "too many entries" if @entries.size >= MAX_ENTRIES
    raise Error, "#{name} is too large" if size > MAX_SIZE

    dos_time, dos_date = dos(time)
    entry = Entry.new(name, size, crc, dos_time, dos_date, @offset)
    raise Error, "the archive is too large" if @offset + size > MAX_SIZE

    put([ 0x04034b50, 20, UTF8_NAMES, 0, dos_time, dos_date, crc, size, size, name.bytesize, 0 ].pack("VvvvvvVVVvv") + name)
    yield @io
    @offset += size
    @entries << entry
  end

  def central_header(entry)
    [ 0x02014b50, 20, 20, UTF8_NAMES, 0, entry.dos_time, entry.dos_date, entry.crc, entry.size, entry.size,
      entry.name.bytesize, 0, 0, 0, 0, 0, entry.offset ].pack("VvvvvvvVVVvvvvvVV") + entry.name
  end

  def put(bytes)
    @io.write(bytes)
    @offset += bytes.bytesize
  end

  def check_name(name)
    name = name.to_s.dup.force_encoding(Encoding::UTF_8)
    parts = name.split("/", -1)
    if !name.valid_encoding? || name.empty? || name.bytesize > 0xFFFF || name.match?(/[\x00-\x1f\x7f\\]/) ||
       name.start_with?("/") || parts.any? { |part| part.empty? || part == "." || part == ".." } || name.match?(/\A[A-Za-z]:/)
      raise Error, "unsafe entry name: #{name.inspect}"
    end
    raise Error, "duplicate entry name: #{name}" if @names[name.downcase]

    @names[name.downcase] = true
    name.b
  end

  # MS-DOS date and time (two-second resolution, from 1980)
  def dos(time)
    time = time.utc
    time = Time.utc(1980, 1, 1) if time.year < 1980
    [ (time.hour << 11) | (time.min << 5) | (time.sec / 2), ((time.year - 1980) << 9) | (time.month << 5) | time.day ]
  end
end
