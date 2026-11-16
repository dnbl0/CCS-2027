# frozen_string_literal: true

# A tiny valid PDF with one line of text, written in Ruby so no binary fixture is kept (CCS-36). The cross-reference table is
# computed, so any reader accepts it.
module PdfFixture
  module_function

  def build(text)
    stream = "BT /F1 18 Tf 72 720 Td (#{text.gsub(/[()\\]/) { |c| "\\#{c}" }}) Tj ET"
    objects = [
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
      "<< /Length #{stream.bytesize} >>\nstream\n#{stream}\nendstream",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    ]
    body = +"%PDF-1.4\n"
    offsets = objects.each_with_index.map do |object, index|
      offset = body.bytesize
      body << "#{index + 1} 0 obj\n#{object}\nendobj\n"
      offset
    end
    xref = body.bytesize
    body << "xref\n0 #{objects.size + 1}\n0000000000 65535 f \n"
    offsets.each { |offset| body << format("%010d 00000 n \n", offset) }
    body << "trailer\n<< /Size #{objects.size + 1} /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n"
    body
  end

  def write(dir, name, text)
    path = File.join(dir, name)
    File.binwrite(path, build(text))
    path
  end
end
