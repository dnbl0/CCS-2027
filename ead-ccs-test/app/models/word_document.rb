# frozen_string_literal: true

require "zlib"

# A small Word document (.docx, Office Open XML) built in Ruby with no extra library (CCS-137: export citations "to a Word doc"
# without losing their format). A heading, then paragraphs of runs, each run plain or italic, set as a reference list is: Times
# New Roman 12 pt, a half-inch hanging indent, a line's space between entries. A .docx is a zip of XML parts; the zip here is the
# simplest kind (stored, not compressed), which Word, LibreOffice, Pages and Google Docs all open.
#
#   WordDocument.new(heading: "References", paragraphs: [ [ [ "Grainger (1922). ", false ], [ "Ukulele", true ] ] ]).to_s
class WordDocument
  MIME_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  FONT = "Times New Roman"
  SIZE = 24 # half-points: 12 pt
  HANGING = 720 # twentieths of a point: half an inch

  # heading: a String; paragraphs: [[ [text, italic?], ... ], ...]
  def initialize(heading:, paragraphs:)
    @heading = heading.to_s
    @paragraphs = paragraphs
  end

  # The .docx file's bytes
  def to_s
    StoredZip.build(
      "[Content_Types].xml" => content_types,
      "_rels/.rels" => package_relationships,
      "word/document.xml" => document
    )
  end

  private

  def content_types
    xml(%(<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">) +
        %(<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>) +
        %(<Default Extension="xml" ContentType="application/xml"/>) +
        %(<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>) +
        %(</Types>))
  end

  def package_relationships
    xml(%(<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">) +
        %(<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>) +
        %(</Relationships>))
  end

  def document
    body = paragraph([ [ @heading, false ] ], bold: true, centred: true) + @paragraphs.map { |runs| paragraph(runs, hanging: true) }.join
    xml(%(<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>#{body}) +
        %(<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>) +
        %(</w:body></w:document>))
  end

  def paragraph(runs, bold: false, centred: false, hanging: false)
    properties = +%(<w:pPr><w:spacing w:after="240" w:line="360" w:lineRule="auto"/>)
    properties << %(<w:ind w:left="#{HANGING}" w:hanging="#{HANGING}"/>) if hanging
    properties << %(<w:jc w:val="center"/>) if centred
    properties << "</w:pPr>"
    "<w:p>#{properties}#{runs.map { |text, italic| run(text, italic: italic, bold: bold) }.join}</w:p>"
  end

  def run(text, italic: false, bold: false)
    style = %(<w:rFonts w:ascii="#{FONT}" w:hAnsi="#{FONT}" w:cs="#{FONT}"/>#{'<w:b/>' if bold}#{'<w:i/>' if italic}<w:sz w:val="#{SIZE}"/>)
    %(<w:r><w:rPr>#{style}</w:rPr><w:t xml:space="preserve">#{escape(text)}</w:t></w:r>)
  end

  # XML 1.0 cannot carry control characters other than tab and newline: they are dropped
  def escape(text) = ERB::Util.html_escape(text.to_s.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, ""))

  def xml(body) = %(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n#{body})

  # A zip archive with every file stored as it is (method 0), names in UTF-8: the local headers and data, the central directory,
  # and its end record (PKWARE APPNOTE 4.3). Enough for a few small XML parts; not for large or many files (no zip64).
  module StoredZip
    module_function

    def build(files)
      out = "".b
      central = "".b
      files.each do |name, content|
        name = name.b
        data = content.to_s.b
        crc = Zlib.crc32(data)
        offset = out.bytesize
        common = [ 20, 0x0800, 0, 0, 0x21, crc, data.bytesize, data.bytesize, name.bytesize, 0 ].pack("vvvvvVVVvv")
        out << [ 0x04034b50 ].pack("V") << common << name << data
        central << [ 0x02014b50, 20 ].pack("Vv") << common << [ 0, 0, 0, 0, offset ].pack("vvvVV") << name
      end
      directory = out.bytesize
      out << central
      out << [ 0x06054b50, 0, 0, files.size, files.size, central.bytesize, directory, 0 ].pack("VvvvvVVv")
    end
  end
end
