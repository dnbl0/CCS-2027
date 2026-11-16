# Uploading metadata from a CSV (CCS-31)

Staff can prepare records in a spreadsheet, save as CSV, check it, and turn it into the JSON Solr takes. There is no upload
page (no sign-in, and rule 10 allows no new page types), so this is two commands on the server, like `records:suppress`.
Nothing here indexes into the shared Solr.

```
bin/rails "records:validate_csv[path/to/file.csv]"      # report problems per row; indexes nothing
bin/rails "records:csv_to_documents[path/to/file.csv]"  # print the Solr JSON (OUT=docs.json writes a file)
```

`records:validate_csv` prints one CSV line per problem (`line,id,problem`; a value that starts like a formula is made safe),
then a summary on the error stream, and exits 1 if anything needs fixing. `records:csv_to_documents` refuses a file with problems.

To index the result into a core you own, set `INDEX=1` and `SOLR_URL` to that core. Port 8984 (the shared, read-only Solr) is
refused. Without `INDEX=1` the task never contacts Solr.

## Headers

Matched ignoring case, spaces and underscores (`Accession Number` is `accession_number`). Only `id` and `title` are required.
A column not in this table is listed as unknown and ignored. Several values in one cell are separated by `;`.

| Header | Becomes (Solr field) | Notes |
|---|---|---|
| `id` | `id` as `csv-<id>`, `source_identifier_ssi` | Required, unique in the file. Letters, digits and `. _ : -`; at most 100 |
| `title` | `title_tsim`, `title_si` | Required; at most 500 characters |
| `accession_number` | `accession_number_ssim` | |
| `collection` | `collection_ssim` | |
| `object_type` | `object_type_ssim` | `;` list |
| `creator` | `creator_tsim`, `creator_ssim`, `creator_display_ssim` | `;` list |
| `date` | `production_date_ssim`, `date_start_isi`, `date_end_isi` | Needs a four-digit year from 1000 ("Circa 1845", "1920-1925") |
| `description` | `description_tsim` | At most 10,000 characters |
| `subject` | `subject_ssim`, `subject_tsim` | `;` list |
| `place` | `production_place_ssim` | `;` list |
| `credit_line` | `credit_line_tsim` | |
| `rights` | `rights_ssim`, `licence_type_ssim` | A leading `[Licence]` sets the licence type, as in the EMu export |
| `language` | `language_ssim` | `;` list of language codes or names |
| `source_reference` | `source_reference_tsim` | |

Every other cell is limited to 2,000 characters. A sample is in `test/fixtures/files/sample-metadata.csv`.

## What is checked, per row

A missing id or title; an id with characters outside the list; a duplicate id (the line of the first is named); a date with no
year; a value over its limit; a column that appears twice; unknown and missing columns; a file that is empty or is not valid CSV.

## Files

The file may start with a byte-order mark, be UTF-16 (Excel "Unicode Text") or Windows-1252 (an older Excel "CSV"); it is read as
UTF-8 text in every case. Fields with commas or line breaks must be quoted, as a spreadsheet does when it saves.

## What this does not do

- No upload page and no approval step: that waits for sign-in (SSO).
- Images are not attached by the CSV; they follow `config/digital_assets.yml` by accession number or record id, as for other records.
- Indexing into the production core, and the choice of who may do it, is for the dev team and the collections team.
