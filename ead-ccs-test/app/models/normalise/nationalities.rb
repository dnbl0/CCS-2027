# frozen_string_literal: true

module Normalise
  # The Nationality filter's terms from nationality_ssim's free text, with the list in config/nationalities.yml (placeholder, for the
  # collections team): "Australian composer and pianist" gives Australian; "Swedish - American artist" Swedish and American; "Born
  # Germany. Lived and worked in Australia" German and Australian. Text that names no nationality on the list gives none.
  module Nationalities
    CONFIG = Rails.root.join("config/nationalities.yml")

    def self.config = (@config ||= YAML.safe_load_file(CONFIG).freeze)
    def self.reload! = (@config = @pattern = @lookup = nil)

    # value: one nationality_ssim value. Returns its nationalities, in the order the text names them.
    def self.terms(value)
      value.to_s.scan(pattern).map { |(word)| lookup.fetch(word.downcase) }.uniq
    end

    # Every word or phrase on the list (downcased) => its nationality
    def self.lookup
      @lookup ||= config.each_with_object({}) do |(nationality, words), map|
        ([ nationality ] + Array(words)).each { |word| map[word.to_s.downcase] = nationality }
      end
    end

    # Longest first, so "South African" wins over "African" and "United States of America" over "America"
    def self.pattern
      @pattern ||= /(?<![[:alnum:]])(#{lookup.keys.sort_by { |word| -word.length }.map { |word| Regexp.escape(word) }.join('|')})(?![[:alnum:]])/i
    end
  end
end
