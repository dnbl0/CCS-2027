# frozen_string_literal: true

# A smaller rendition of a Nexus DAM picture (Widen's embed links take the width as ?w=): the Places wall's tiles are a few hundred pixels
# wide, so they ask for that rather than the 1,000px the index keeps. Any other address is returned as it is.
module DamImage
  HOSTS = %w[unimelbourne.widen.net].freeze

  module_function

  def sized(url, width)
    uri = URI.parse(url.to_s)
    return url unless uri.host && HOSTS.include?(uri.host) && uri.query.to_s.match?(/(\A|&)w=\d+/)

    uri.query = uri.query.sub(/(\A|&)w=\d+/) { "#{Regexp.last_match(1)}w=#{width.to_i}" }
    uri.to_s
  rescue URI::InvalidURIError
    url
  end
end
