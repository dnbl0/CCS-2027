# De-bias notices: the term list (for the collections team)

Some words in older catalogue records are now seen as offensive, inaccurate or outdated. This site can point those words out to
visitors. This page explains how you supply the words, how the site uses them, and what it does not do.

**Status: the mechanism is built; the list is empty.** No real term is in the system. All wording a visitor sees about this
(the notice, and the page "About the language in our records") is placeholder wording that the collections team and the
University's Indigenous advisers must write or approve before the site relies on it.

## What visitors see

When a record's displayed text (title, description, subjects, places, names, material) contains a term on your list, the record
page shows:

- a notice near the top, "This record contains language that may be offensive or outdated", which shows each term in the words
  around it, says why it may be offensive or outdated (your explanation), and suggests another term if you gave one;
- the term marked where the record shows it (underlined and tinted, and read out by screen readers as "flagged term");
- links to the public page "About the language in our records" (`/language-in-our-records`) and to "Contact the collection team",
  which is how a visitor suggests a correction.

The site **never changes or hides** the record's words. Terms are shown as they appear in the original catalogue records. The
site only adds the notice and the mark. Nothing is stored about the visitor. It works without JavaScript.

## What it does not do

- It does not decide that a record is offensive. It finds listed words and phrases, nothing else.
- It matches whole words (or a phrase, or the start of a word). It misses other spellings and typing errors, and it cannot tell a
  respectful or quoted use from an offensive one. List the variants you want.
- It does not read fields the page does not show, such as internal restriction notes, so it cannot reveal them.
- It does not mark the search results list or the search box, and it does not change what a search finds.
- It does not look at the records' language (the index has no language field yet). The `languages` column is for reviewers.
- Notes and inscriptions are not in the index yet; entries for them are accepted and start working when the fields arrive.

## The spreadsheet

Make a spreadsheet with one row for each term and these column headings, then save it as **CSV UTF-8**. Headings are not case
sensitive and the order does not matter.

| Column | Needed | What to put |
|---|---|---|
| `term` | yes | The word or phrase as it is written in records. Plain text only: no `*`, `?`, brackets or other pattern characters |
| `match` | no | `word` (a whole word; the default), `phrase` (two or more words in order) or `prefix` (any word that starts with it, three letters or more) |
| `case` | no | `insensitive` (the default) or `sensitive` (only this capitalisation) |
| `languages` | no | Language codes, separated by `;` (for example `en; fr`). Default `en`. Kept for reviewers |
| `fields` | no | Where to look, separated by `;`: `all` (the default), or any of `title`, `description`, `subject`, `place`, `names`, `material`, `notes`, `inscription` |
| `explanation` | yes | Plain-language reason the term may be offensive or outdated. Visitors read this, so write it for them (up to 1000 characters) |
| `alternative` | no | A more current term to suggest |
| `severity` | no | `note` (outdated or imprecise; the default) or `caution` (may cause offence or distress) |
| `source` | yes | Who proposed the term and where the explanation comes from (a person or team, a style guide, an adviser) |
| `reviewed_on` | yes | The date a person last reviewed the entry, as `2026-11-03` |
| `enabled` | no | `yes` to use it on the site. Blank or `no` keeps it on the list but switched off |
| `id` | no | A short label (`some-term`); made from the term if left out. Needed to keep two entries that differ only by capital letters |

## Loading the list

The developers run these on the team's behalf:

1. `bin/rails debias:import CSV=path/to/terms.csv` checks every row and either reports every problem with its row number and
   writes nothing, or writes `config/debias_terms.yml`. The spreadsheet replaces the whole list each time, so keep it as the
   master copy. `OUT=somewhere.yml` writes to another file to try it first.
2. `bin/rails debias:report` lists each enabled term, how many records it appears in and how many times, with example record
   numbers. It only reads the index. A term that appears in no record shows zero; a term in thousands is worth a second look.
3. The change goes through the usual review (a pull request) and release; the site reads the list when it starts.

## Review process (proposed)

1. The collections team drafts terms and explanations; `enabled` stays `no`.
2. Indigenous advisers review the Indigenous and colonial-era terms, the explanations and the notice wording.
3. Run the report to see which records are affected, and read a sample of them.
4. Switch the entries to `yes`, set `reviewed_on`, and import.
5. Review the list on a schedule (suggested: yearly), and when a visitor suggests a correction.

## For developers

- `config/debias_terms.yml` is the list and documents its own schema. `DebiasTerms` loads it, compiles matchers (escaped literals
  between word boundaries; no pattern from the list is ever run as a pattern), and scans only the text the record page displays.
  Input is bounded (10,000 characters of a value, 50 values of a field, 100 finds) and each pattern has a time limit.
- An unreadable list or a bad entry is logged and skipped, never an error page.
- With an empty list the scan returns at once and the record page is unchanged. 300 terms cost about 3 ms a record page; see
  `test/integration/debias_performance_test.rb`.
- Tests use made-up words only (`test/support/debias_helper.rb`). Never put a real term in a test, a fixture or a commit message.
