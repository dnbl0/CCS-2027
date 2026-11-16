# Chinese, Japanese and Korean search (CCS-56, East Asian Collections)

Records with titles, creators, subjects or descriptions in Chinese, Japanese or Korean can be found by any run of characters
inside them, without a word list. English search is unchanged.

## What changed in `solr/conf`

- A field type `text_cjk` (`schema.xml`): everything that is not a Han, Hiragana, Katakana or Hangul character is replaced by a
  space; half-width and full-width forms are made the same (`CJKWidthFilter`); the characters are indexed singly and in
  overlapping pairs (`CJKBigramFilter`, `outputUnigrams="true"`). A search for `水畫`, `山水畫`, `畫` or `항아리` therefore finds
  `山水畫卷` or `달항아리`. Latin text never reaches these fields, so the English analysis and ranking do not change.
- Fields `title_cjk`, `creator_cjk`, `subject_cjk`, `description_cjk` and `all_text_cjk`, filled by `copyField` from the existing
  title, alternative title, creator, subject and description fields and (for `all_text_cjk`) from every text field. Nothing in the
  indexers changes: the records already carry the text.
- `solrconfig.xml`: `all_text_cjk^0.5` joins the default `qf` (so "All Fields" finds CJK text), the CJK fields join the title,
  creator and subject searches, and there are two new handler defaults, `cjk_qf` and `description_qf`.
- `language_ssim` is filled when the source has a language column (the metadata CSV of CCS-31). The EMu and
  Vernon exports have no language column that is not already `language_group_ssim`, so it is not filled from them.

## In the app

A search option "Chinese, Japanese, Korean" searches the CJK fields only, and the Description search also looks in
`description_cjk`. Both are offered only when the core has the fields (`CjkIndex`): the app asks Solr's schema on a results page, at
most every ten minutes, and treats "cannot ask" as "not there". A core made before this change therefore works exactly as before.
The option is not in the advanced search form. Wording of the option is placeholder.

## Proving it

`test/lib/solr_cjk_config_test.rb` checks the configuration and, against a core built from `solr/conf` (the CI `system` job's),
the tokens a text is analysed into. It was also run end to end on a throwaway Solr 10 core (docker, port 8995, removed
afterwards) with the sample records in `test/fixtures/files/cjk-sample-docs.json`: every substring above found its record, in
All Fields, the CJK option and the Title, Creator and Description searches, and `violin` found only the English record.

## What this does not do (needs the dev team)

- **The shared and production indexes need the new configuration and a reindex.** The schema and `solrconfig.xml` must be
  applied to the core and the records indexed again, because `copyField` fills the new fields at index time. Until then the CJK
  option stays hidden. Not done by this change.
- No dictionary segmentation: a pair of characters can match across a word boundary, which is the price of searching without a
  word list. Ranking is by characters, so a long query ranks records that hold it whole above those that hold pieces of it.
- Spelling suggestions and the search-box suggester still use the English fields.
- Transliteration (pinyin, romaji), simplified/traditional Chinese folding and a language filter are not built.
