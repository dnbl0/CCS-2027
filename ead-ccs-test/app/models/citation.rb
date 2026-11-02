# frozen_string_literal: true

# Citations for a record (CCS-131, CCS-137) in the four styles the stories name: APA 7th, MLA 9th, Chicago 17th (notes and
# bibliography) and Harvard (Australian author-date). Turabian was dropped from both stories. This module is the only
# place a citation is built; the views only show what it returns. The records are museum, library and archive objects, not
# books, so each style is its object form: the creators, date and title, then the object type, the collection that holds
# it (the University of Melbourne), its accession number, the persistent link and the day it was looked at.
#
#   source = Citation.source_for(document, url: "https://ccs.example/catalog/emu-1")
#   Citation.format(source, :apa, accessed: Date.current)   # => "Grainger, P. A. (1922). ..."
#
# Citations are plain text (they are copied and downloaded as text), so titles are not italicised. Missing parts are left
# out, never shown as blanks: no creator moves the title to the front, no date is "n.d.", no accession number no line.
module Citation
  STYLES = %i[apa mla chicago harvard].freeze
  LABELS = { apa: "APA 7th", mla: "MLA 9th", chicago: "Chicago 17th", harvard: "Harvard" }.freeze
  PUBLISHER = "University of Melbourne"
  PLACE = "Melbourne"
  MONTHS = %w[January February March April May June July August September October November December].freeze
  UNKNOWN_CREATOR = /\A(unknown|anonymous|not recorded|n\/?a)\b/i

  # A creator: a person ("Surname, Given names") or an organisation (the whole name in family)
  Name = Data.define(:family, :given) do
    def person? = given.present?

    # "P. A." (APA) or "P.A." (Harvard) from "Percy Aldridge"
    def initials(spaced: true)
      given.split(/[\s-]+/).filter_map { |part| part[0]&.upcase&.+(".") }.join(spaced ? " " : "")
    end
  end

  # What a style needs from a record. year is "1922", "c. 1922" or nil.
  Source = Data.define(:title, :creators, :year, :object_type, :collection, :accession, :url)

  module_function

  def styles = STYLES

  def label(style) = LABELS.fetch(style.to_sym)

  # A style from a request's parameter, or APA when it is missing or unknown
  def style_from(value) = STYLES.find { |style| style.to_s == value.to_s } || STYLES.first

  def source_for(document, url:)
    Source.new(
      title: first_value(document, "title_tsim") || "Untitled",
      creators: Array(document["creator_ssim"]).filter_map { |value| parse_name(value) }.uniq,
      year: year_of(first_value(document, "production_date_ssim"), document["date_start_isi"]),
      object_type: first_value(document, "object_type_ssim"),
      collection: first_value(document, "collection_ssim"),
      accession: first_value(document, "accession_number_ssim"),
      url: url
    )
  end

  # One citation as a line of text
  def format(source, style, accessed:)
    send(:"#{style_from(style)}_citation", source, accessed)
  end

  # Many citations in a style, in the alphabetical order a reference list has (by the creator, else the title)
  def reference_list(sources, style, accessed:)
    sources.sort_by { |source| sort_key(source) }.map { |source| format(source, style, accessed: accessed) }
  end

  # ---- parsing -------------------------------------------------------------------------------------------------------

  # "Grainger, Percy Aldridge" -> person; "A. M. Bickford & Sons (estab. 1863), author" -> organisation. Birth and death
  # dates in brackets and a trailing role ("..., author", "..., publisher/publishing") are not part of the name.
  def parse_name(value)
    text = value.to_s.gsub(/\s*\([^)]*\)\s*(?=,|\z)/, "").squish
    text = text.sub(/,\s*[a-z][a-z\/ &-]*\z/, "") if text.count(",") >= 1 && text.split(",").last.strip.match?(/\A[a-z][a-z\/ &-]*\z/)
    return nil if text.blank? || text.match?(UNKNOWN_CREATOR)

    family, given = text.split(",", 2).map { |part| part.delete("()").squish }
    given.present? && !given.match?(/\A[a-z]/) ? Name.new(family: family, given: given) : Name.new(family: text.delete("()").squish, given: nil)
  end

  # 1922 from "c. 1922", "26 July 1896", "Dec-47" (no year: the indexed start year), nil when there is none
  def year_of(date_text, start_year)
    found = date_text.to_s[/\b(1\d{3}|20\d{2})\b/, 1] || start_year&.to_s.presence
    return nil unless found

    date_text.to_s.match?(/\b(c\.|ca\.?|circa)\s*\d/i) ? "c. #{found}" : found
  end

  def first_value(document, field) = Array(document[field]).first.to_s.squish.presence

  # ---- the four styles -----------------------------------------------------------------------------------------------

  # Grainger, P. A., & Smith, J. (1922). Title [ukulele]. Grainger Museum Collection, University of Melbourne. Accession
  # number 00.0001. https://... Retrieved 2 November 2026.
  def apa_citation(source, accessed)
    names = source.creators.map { |name| name.person? ? "#{name.family}, #{name.initials}" : name.family }
    authors = names.size > 1 ? "#{names[0..-2].join(', ')}, & #{names.last}" : names.first
    title = [ source.title, (" [#{source.object_type}]" if source.object_type) ].join
    lead = authors ? "#{authors} (#{source.year || 'n.d.'}). #{title}" : "#{title} (#{source.year || 'n.d.'})"
    join_parts(lead, holder(source), accession(source, "Accession number"), source.url, "Retrieved #{date_text(accessed)}.")
  end

  # Grainger, Percy Aldridge, and John Smith. Title. Ukulele, c. 1922, Grainger Museum Collection, University of Melbourne,
  # accession number 00.0001. https://... Accessed 2 Nov. 2026.
  def mla_citation(source, accessed)
    names = source.creators.map.with_index { |name, i| name.person? && i.zero? ? "#{name.family}, #{name.given}" : full_name(name) }
    authors = case names.size
    when 0 then nil
    when 1 then names.first
    when 2 then names.join(", and ")
    else "#{names.first}, et al"
    end
    details = [ source.object_type&.capitalize, source.year || "n.d.", source.collection, PUBLISHER, accession(source, "accession number") ].compact.join(", ")
    join_parts(authors, source.title, details, source.url, "Accessed #{date_text(accessed, abbreviate: true)}.")
  end

  # Grainger, Percy Aldridge, and John Smith. Title. Ukulele. Grainger Museum Collection, accession 00.0001. Melbourne:
  # University of Melbourne, 1922. https://... (accessed 2 November 2026).
  def chicago_citation(source, accessed)
    names = source.creators.map.with_index { |name, i| name.person? && i.zero? ? "#{name.family}, #{name.given}" : full_name(name) }
    names = names.first(7) + [ "et al" ] if names.size > 10
    authors = names.size > 1 ? "#{names[0..-2].join(', ')}#{names.size > 2 ? ',' : ''} and #{names.last}" : names.first
    held = [ source.collection, (accession(source, "accession") if source.accession) ].compact.join(", ").presence
    publication = "#{PLACE}: #{PUBLISHER}, #{source.year || 'n.d.'}"
    join_parts(authors, source.title, source.object_type&.capitalize, held, publication, "#{source.url} (accessed #{date_text(accessed)}).")
  end

  # Grainger, P.A. & Smith, J. 1922, Title [ukulele], Grainger Museum Collection, University of Melbourne, Melbourne,
  # accession number 00.0001, viewed 2 November 2026, <https://...>.
  def harvard_citation(source, accessed)
    names = source.creators.map { |name| name.person? ? "#{name.family}, #{name.initials(spaced: false)}" : name.family }
    names = [ "#{names.first} et al." ] if names.size > 3
    authors = names.size > 1 ? "#{names[0..-2].join(', ')} & #{names.last}" : names.first
    title = [ source.title, (" [#{source.object_type}]" if source.object_type) ].join
    lead = authors ? "#{authors} #{source.year || 'n.d.'}, #{title}" : "#{title} #{source.year || 'n.d.'}"
    rest = [ holder(source), PLACE, accession(source, "accession number"), "viewed #{date_text(accessed)}", "<#{source.url}>" ].compact.join(", ")
    "#{lead}, #{rest}."
  end

  # ---- pieces --------------------------------------------------------------------------------------------------------

  def holder(source) = [ source.collection, PUBLISHER ].compact.join(", ")

  def accession(source, words) = (source.accession ? "#{words} #{source.accession}" : nil)

  def full_name(name) = name.person? ? "#{name.given} #{name.family}" : name.family

  # "2 November 2026", or "2 Nov. 2026" for MLA
  def date_text(date, abbreviate: false)
    month = MONTHS[date.month - 1]
    month = month.length > 4 ? "#{month[0, 3]}." : month if abbreviate
    "#{date.day} #{month} #{date.year}"
  end

  # Parts as sentences: each ends in one full stop (not two after "Co." or a title ending in "?"). A link is left as it is.
  def join_parts(*parts)
    parts.compact.map { |part| part.match?(%r{\Ahttps?://}) || part.match?(/[.?!]\z/) ? part : "#{part}." }.join(" ")
  end

  def sort_key(source)
    lead = source.creators.first
    [ (lead ? lead.family : source.title).downcase.gsub(/\A(the|a|an)\s+/, ""), source.year.to_s, source.title.downcase ]
  end
end
