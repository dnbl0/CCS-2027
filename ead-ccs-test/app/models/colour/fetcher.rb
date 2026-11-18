# frozen_string_literal: true

require "net/http"
require "open3"

module Colour
  # Gets a record's thumbnail as a small PNG, from the allowed places only:
  #
  # - the DAM's public embed links on an allowed host (COLOUR_IMAGE_HOSTS, default unimelbourne.widen.net), over https. The link is
  #   rewritten to ask the DAM for a PNG 64 pixels wide (/content/<id>/png/<name>.png?w=64, keeping its u= key), so little is
  #   downloaded and Colour::Png can read it;
  # - this site's own /digital-assets/ files, read from public/ (no request made). They are JPEGs: they are read only when the
  #   libvips command line (vipsthumbnail) is installed, which turns them into a small PNG; otherwise they are reported.
  #
  # Anything else is refused (Colour::Fetcher::Refused) and nothing is requested. Redirects are not followed.
  class Fetcher
    class Refused < StandardError; end
    class Failed < StandardError; end

    WIDTH = 64
    MAX_BYTES = 2 * 1024 * 1024
    LOCAL_PREFIX = "/digital-assets/"
    DEFAULT_HOSTS = %w[unimelbourne.widen.net].freeze

    def self.hosts = ENV["COLOUR_IMAGE_HOSTS"].presence&.split(",")&.map(&:strip)&.reject(&:blank?) || DEFAULT_HOSTS

    # get: ->(uri) { [ status, content_type, body ] } (tests pass their own; nothing is requested then)
    def initialize(get: method(:http_get), public_root: Rails.public_path, hosts: self.class.hosts)
      @get = get
      @public_root = Pathname(public_root).expand_path
      @hosts = hosts
    end

    # The PNG bytes for a thumbnail path or link
    def png(path)
      bytes = path.to_s.start_with?(LOCAL_PREFIX) ? local(path) : remote(path)
      Png.png?(bytes) ? bytes : convert(bytes)
    end

    # The link actually requested for a DAM thumbnail (nil when it is not allowed)
    def remote_uri(link)
      uri = URI.parse(link.to_s)
      return nil unless uri.is_a?(URI::HTTPS) && @hosts.include?(uri.host) && uri.userinfo.nil? && uri.port == 443

      parts = uri.path.split("/")
      return nil unless parts[1] == "content" && parts.size >= 5

      name = File.basename(parts[4..].join("/"), ".*")
      uri.path = [ "", "content", parts[2], "png", "#{name}.png" ].join("/")
      key = URI.decode_www_form(uri.query.to_s).to_h["u"]
      uri.query = URI.encode_www_form({ w: WIDTH, u: key }.compact)
      uri
    rescue URI::InvalidURIError
      nil
    end

    private

    def remote(link)
      uri = remote_uri(link) || raise(Refused, "not an allowed image address")
      status, type, body = @get.call(uri)
      raise Failed, "HTTP #{status}" unless status.to_i == 200
      raise Failed, "not an image (#{type})" unless type.to_s.start_with?("image/")
      raise Failed, "image too large" if body.to_s.bytesize > MAX_BYTES

      body.to_s.b
    end

    def local(path)
      root = @public_root.join(LOCAL_PREFIX.delete_prefix("/").chomp("/")).to_s
      file = @public_root.join(URI::DEFAULT_PARSER.unescape(path.to_s.split("?").first).delete_prefix("/")).expand_path
      raise Refused, "outside #{LOCAL_PREFIX}" unless file.to_s.start_with?("#{root}/")
      raise Failed, "no such file" unless file.file?
      raise Refused, "outside #{LOCAL_PREFIX}" unless file.realpath.to_s.start_with?("#{Pathname(root).realpath}/") # no way out by a link
      raise Failed, "image too large" if file.size > MAX_BYTES

      file.binread
    end

    # A JPEG (or other format) through the libvips command line, when it is installed
    def convert(bytes)
      Dir.mktmpdir("colour") do |dir|
        input = File.join(dir, "in")
        output = File.join(dir, "out.png")
        File.binwrite(input, bytes)
        _out, error, status = Open3.capture3("vipsthumbnail", input, "--size", WIDTH.to_s, "-o", output)
        raise Failed, "could not read the image (#{error.strip.first(80)})" unless status.success? && File.exist?(output)

        File.binread(output)
      end
    rescue Errno::ENOENT
      raise Failed, "not a PNG, and vipsthumbnail is not installed"
    end

    def http_get(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
        response = http.request(Net::HTTP::Get.new(uri, "User-Agent" => "CollectionsNavigator-colour/1.0"))
        [ response.code.to_i, response["content-type"], response.body ]
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
      raise Failed, e.class.name
    end
  end
end
