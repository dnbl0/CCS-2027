# frozen_string_literal: true

class CollectionStories
  # The accession numbers a story page may be about. Stories rarely print the number in their text, but their image files are often
  # named after it (00.0099c.JPG is part or view "c" of 00.0099) and their captions and credit lines often end with it
  # ("Grainger Museum Collection, 01.0397"). These are only candidates: the harvest keeps one when it names exactly one record of
  # the story's collection (CollectionStories::Harvester), so a date or a phone number that looks like a number does no harm.
  #
  # Normalised: a "GMC " prefix and a trailing part or view letter are dropped. Shapes read:
  #   NN.NNNN or NNNN.NNNN, with optional .N sub-parts   00.0099, 1996.5000, 01.3524.1 (Grainger: year and number)
  #   NNNN/N[/N...] with optional -N                     2017/23/2/2, 2016/1/1/4, 2017/8-5/1 (text only)
  # In a file name an underscore may stand for the point (01_3321_Label-MF.jpg); in running text it may not.
  module Candidates
    PREFIX = /(?:GMC[\s_-]*)?/i
    DOTTED = /(?<![\w.\/])#{PREFIX}(\d{2}|\d{4})\.(\d{4})((?:\.\d{1,3})*)(?:[a-z](?![a-z]))?(?![\d\/])/i
    FILE_DOTTED = /(?<![a-z\d.])#{PREFIX}(\d{2}|\d{4})[._](\d{4})((?:\.\d{1,3})*)(?:[a-z](?![a-z]))?(?!\d)/i
    SLASHED = /(?<![\w.\/-])#{PREFIX}(\d{4}\/\d{1,4}(?:[\/-]\d{1,4})*)(?![\w\/])/i

    module_function

    # The last part of an image address, without its extension: never the folder numbers (/0003/2357328/)
    def from_file_name(url)
      name = URI::DEFAULT_PARSER.unescape(url.to_s.split(/[?#]/).first.to_s.split("/").last.to_s).sub(/\.[a-z0-9]{2,4}\z/i, "")
      name.scan(FILE_DOTTED).map { |year, number, parts| "#{year}.#{number}#{parts}" }.uniq
    end

    def from_text(text)
      text = text.to_s
      found = text.to_enum(:scan, DOTTED).map { [ Regexp.last_match.begin(0), Regexp.last_match.captures.then { |y, n, p| "#{y}.#{n}#{p}" } ] } +
              text.to_enum(:scan, SLASHED).map { [ Regexp.last_match.begin(0), Regexp.last_match[1] ] }
      found.sort_by(&:first).map(&:last).uniq
    end
  end
end
