#!/usr/bin/env ruby
# Checks the app's own locale strings with no gem and no Rails boot (about a second). Run: ruby script/i18n_check.rb
#
#   missing  a literal key in t("nexus_ccs...") / t("seo...") / t("catalog...") or a lazy t(".key") in a view that is in no locale file
#   unused   a key under nexus_ccs, seo or catalog that nothing in app/, lib/ or config/ refers to
#
# A key built with interpolation (t("nexus_ccs.sensitivity.#{state}.title")) counts every key under its static prefix as used.
# Keys under blacklight, kaminari, activerecord and views are overrides read by gems or Rails, so they are not checked.
# Exit status is 1 when there is a problem, so bin/ci can fail on it. With --missing-only a key nobody uses yet is not a
# problem (test/lib/i18n_check_test.rb runs it that way, so a story that adds its strings before its views is not blocked). See docs/how-to-change.md ("Add a locale string").
require "yaml"

ROOT = File.expand_path("..", __dir__)
OWN_NAMESPACES = %w[nexus_ccs seo catalog].freeze

def flatten(hash, prefix = nil)
  hash.flat_map do |key, value|
    path = [ prefix, key ].compact.join(".")
    value.is_a?(Hash) ? flatten(value, path) : [ path ]
  end
end

locale_files = Dir[File.join(ROOT, "config/locales/**/*.yml")]
keys = locale_files.flat_map { |f| flatten(YAML.load_file(f).fetch("en", {})) }.uniq
own_keys = keys.select { |k| OWN_NAMESPACES.include?(k.split(".").first) }

sources = Dir[File.join(ROOT, "{app,lib,config}/**/*.{rb,erb,yml}")].reject { |f| f.include?("/config/locales/") }
text = sources.to_h { |f| [ f, File.read(f) ] }

literal_refs = []   # [key, file] for every t("...") call with a literal key
dynamic_prefixes = []
string_literals = []
text.each do |file, body|
  body.scan(/\b(?:I18n\.)?(?:t|translate)\(\s*["']([^"']+)["']/) do |(key)|
    key = lazy_key(file, key) if key.start_with?(".")
    next unless key

    if key.include?("\#{")
      prefix = key.split("\#{").first
      dynamic_prefixes << prefix if prefix.include?(".") # t("#{scope}.title") has no static part to match
    else
      literal_refs << [ key, file ]
    end
  end
  body.scan(/["']([a-z_]+(?:\.[a-z_0-9]+)+)["']/) { |(s)| string_literals << s }
  body.scan(/["']([a-z_]+(?:\.[a-z_0-9]+)+\.)\#\{/) { |(s)| dynamic_prefixes << s }
  # a scope kept in a variable (key = "nexus_ccs.access_requests.fields", then t("\#{key}.name")) uses everything under it
  body.scan(/=\s*["']([a-z_]+(?:\.[a-z_0-9]+)+)["']/) { |(s)| dynamic_prefixes << "#{s}." }
end

BEGIN {
  # app/views/catalog/_country_acknowledgement.html.erb -> "catalog.country_acknowledgement" + key
  def lazy_key(file, key)
    match = file.match(%r{app/views/(.+?)/_?([^/]+?)\.html\.erb\z}) or return nil
    "#{match[1].tr('/', '.')}.#{match[2]}#{key}"
  end
}

missing = literal_refs.reject { |key, _| !OWN_NAMESPACES.include?(key.split(".").first) || keys.include?(key) || keys.any? { |k| k.start_with?("#{key}.") } }
used = own_keys.select do |key|
  string_literals.include?(key) || literal_refs.any? { |ref, _| ref == key || key.start_with?("#{ref}.") } ||
    dynamic_prefixes.any? { |prefix| key.start_with?(prefix) }
end
unused = ARGV.include?("--missing-only") ? [] : own_keys - used

puts "#{own_keys.size} locale keys checked (#{keys.size} in all), #{literal_refs.size} literal t() calls"
missing.each { |key, file| puts "MISSING  #{key}  (#{file.delete_prefix("#{ROOT}/")})" }
unused.each { |key| puts "UNUSED   #{key}" }
puts "ok" if missing.empty? && unused.empty?
exit(missing.empty? && unused.empty? ? 0 : 1)
