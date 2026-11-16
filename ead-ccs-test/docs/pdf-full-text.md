# Full text search of PDFs (CCS-36)

A record with a PDF (`config/digital_media.yml`, kind `pdf`) can be found by words inside the PDF, through a search option
"Full text (PDF)". A result found this way says "Found in PDF" (placeholder wording).

## How it works

- **At indexing** (`Collections::DigitalMedia#attach`) the text of each PDF is read with `pdftotext` (Poppler, `Collections::PdfText`)
  and put in the field `pdf_text_tim`. The PDF file is looked for in `PDF_MEDIA_DIR` (default `public/digital-assets/media`),
  under the `file` name in `digital_media.yml`. Machines that index need `pdftotext` installed (`brew install poppler`,
  `apt-get install poppler-utils`); without it the PDFs are skipped with a log line and nothing else changes.
- **The field** (`solr/conf/schema.xml`) is indexed, **not stored**, and named `*_tim` on purpose: no `copyField` rule matches it,
  so the text never reaches the suggester, the spelling dictionary or the default "All Fields" search. Only Full text looks in it.
- **The search option** is offered only when the core has the field (`PdfTextIndex`, asked on a results page at most every ten
  minutes); a core made before this change works as before. It is not in the advanced form.

## Limits and safety

| Setting | Default | Meaning |
|---|---|---|
| `PDF_TEXT` | on | `off` reads no PDF text at indexing |
| `PDF_MEDIA_DIR` | `public/digital-assets/media` | Where the PDF files are on the indexing machine |
| `PDF_TEXT_MAX_MB` | 50 | A larger file is skipped |
| `PDF_TEXT_TIMEOUT` | 30 | Seconds; a slower file is stopped and skipped |
| `PDF_TEXT_MAX_CHARS` | 1,000,000 | Text kept per PDF |

A file that is missing, damaged, encrypted, too big or too slow is logged and skipped; an indexing run never stops for it.
The text of a record whose assets are withheld (not licensed, ICIP) or sensitive is **not indexed**, so a PDF that is not shown cannot
be searched either (`AccessPolicy`, `Sensitivity` are unchanged).

## What this does not do

- **No OCR.** A scanned PDF with no text layer has no text and is not found by Full text. OCR is out of scope.
- **No snippet.** The text is not stored (size, and it is not shown), so Solr cannot highlight it: the card says "Found in PDF"
  and names no passage.
- **The shared and production indexes** need the new configuration applied and the records indexed again, with `pdftotext`
  available. Not done by this change. PDFs must also be listed in `digital_media.yml` and be on the indexing machine.
- Spelling suggestions, the search-box suggester and the default search do not use PDF text.
