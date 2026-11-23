# frozen_string_literal: true

# Rack middleware (lib/middleware, required by config/initializers/email_protection.rb): every email address in an HTML page is
# written with character references (CCS-233: "the displayed email address should be either obfuscated or masked"), its "@" as
# &#64; and its dots as &#46;. A browser shows and follows it exactly as before (the mailto links of CCS-47 still open the
# visitor's email with the record's ID as the subject), and a screen reader reads a normal address; a harvester reading the raw
# HTML for "name@domain" finds none. Script and style blocks are left alone (JSON-LD and code must keep their characters).
class EmailProtection
  ADDRESS = /([A-Za-z0-9._%+-]+)@((?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,})/
  VERBATIM = %r{(<(script|style)\b[^>]*>.*?</\2\s*>)}mi

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    return [ status, headers, body ] unless html?(headers)

    html = +""
    body.each { |part| html << part }
    body.close if body.respond_to?(:close)
    protected_html = self.class.protect(html)
    headers["content-length"] = protected_html.bytesize.to_s if headers.key?("content-length")
    [ status, headers, [ protected_html ] ]
  end

  def self.protect(html)
    html.split(VERBATIM).each_slice(3).map do |text, block, _tag|
      text.gsub(ADDRESS) { "#{Regexp.last_match(1)}&#64;#{Regexp.last_match(2).gsub('.', '&#46;')}" } + block.to_s
    end.join
  end

  private

  def html?(headers)
    type = headers["content-type"] || headers["Content-Type"]
    type.to_s.start_with?("text/html")
  end
end
