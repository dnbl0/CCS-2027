# Stories from the collection

A record page shows a **Stories from the collection** section when one of the University's collection websites has published an
article about that object. The Grainger Museum's "From the collection" series (https://grainger.unimelb.edu.au/from-the-collection)
is the first source. The University has approved linking to these articles.

This is not the same as the site's own **Stories** pages (`/stories`, Markdown files in `content/stories/`, see
[categories-themes-stories.md](categories-themes-stories.md)): those are online exhibitions written for this site. Collection stories
are articles on another University site, linked from the record they are about.

## In plain language

- A story appears on a record only when the record's **accession number and collection both match** the story's, exactly. There is
  no guessing from titles or keywords.
- The record page never contacts another website. It reads one reviewed file, `config/collection_stories.yml`, which is made
  offline by a harvest and checked by a person before it is committed.
- Stories the harvest could not match, or that a reviewer held back, go on a **curator list** in the same file. They are never shown
  on the site.
- No number of stories or records is shown anywhere (the site owner asked for no counts).

## What the visitor sees

Under the record's details, before the similar objects: an h2 "Stories from the collection" and one line of description, then the
stories, after the National Gallery of Art's article listings (nga.gov/stories/articles). The layout depends on how many there are:

- **One story** is a wide row between two rules: the site's name on the left, then an "Article" kicker, the headline and the summary,
  with the picture on the right. On a phone it stacks: the site's name, the picture, then the text.
- **Two or more** are a card grid (two columns for two stories, three for more; one column on a phone). Each card has the picture,
  the kicker ("Article · Grainger Museum"), the headline and the summary.

In every story:

- the headline is an h3 and the link of the whole story (same tab, like every link on the site); it comes first in the reading order;
- the picture is shown whole (never cropped) in a 3:2 frame and lazy-loaded. Its `alt` is empty: the headline names the story.
- **Which picture:** the story's own, from the collection's site. That site may refuse it (a Cloudflare check), so
  `story_image_controller.js` then shows the record's own picture of the object, and if there is none, the story becomes text only.
  A story with no picture of its own starts with the record's picture. A record the visitor may not view, or a sensitive one, gets
  text stories and no picture at all (`AccessPolicy.view?`, `Sensitivity.sensitive?`).
- No number of stories or records is shown.

Components: `CollectionStoriesComponent` (the section and the layout) and `CollectionStoryComponent` (one story); styles in
`collection_stories.css`. The wording is in `config/locales/collection_stories.en.yml` (the description is placeholder wording).

## Files

| File | What it is |
|---|---|
| `config/collection_story_sources.yml` | The sites to harvest: name, collection, list page, story address prefix, and stories held back |
| `config/collection_stories.yml` | The harvest's output: `stories` (read by the record page) and `unmatched` (the curator list) |
| `app/models/collection_stories.rb` | Reads the data file and finds a record's stories (accession number and collection) |
| `app/models/collection_stories/*.rb` | The harvest: `Harvester`, `Fetcher` (https only), `Page` (reads one story), `Candidates` (accession numbers), `SolrMatcher` |
| `lib/tasks/collection_stories.rake` | `bin/rails stories:harvest` |
| `app/components/nexus_ccs/collection_stories_component.*` | The section on the record page (`app/views/catalog/show.html.erb`) |

## How a story is matched

For each story page the harvest collects **candidate accession numbers** from the story's image file names (`00.0099c.JPG` is view
"c" of `00.0099`), its captions and alt text, and its text (`Candidates`: `NN.NNNN`, `NNNN.NNNN`, `NNNN/N/N...`, with a `GMC`
prefix or a trailing view letter dropped). It then asks Solr, for each candidate, which records of **the source's collection** have
exactly that accession number. A candidate that names exactly one record is confirmed; the story is kept with its confirmed numbers.
A story with no candidate, or none that names exactly one record, goes to the curator list with the reason.

The record page then shows a story on any record whose `accession_number_ssim` and `collection_ssim` match one of the story's
confirmed numbers and its collection.

## Harvest

Run it on a machine that can reach the collection websites (the University's sites refuse some cloud and data-centre addresses with a
Cloudflare challenge; a laptop on an ordinary connection works) and the Solr core holding the records:

```sh
cd ead-ccs-test
export SOLR_URL=http://127.0.0.1:8984/solr/blacklight-core
bin/rails stories:harvest                                # writes config/collection_stories.yml
OUT=tmp/collection_stories.yml bin/rails stories:harvest  # or write elsewhere to compare first
```

It prints each matched story with its record ids, each story sent to the curator list with the reason, and any page it could not read.
A page that could not be read is left out of both lists, so check those lines and harvest again if a site was briefly unavailable.

The running app reads the file once per process: restart the server to see a new harvest.

## Review before committing

Look at `git diff config/collection_stories.yml` and, for each new or changed story:

1. Open the story and the record(s) it matched (`record_ids`). Is the story really **about that object**, not one that is only
   pictured or mentioned in passing? If not, hold it (below).
2. Check the title, summary and picture read well on a card. They are the site's own; do not edit them in the file.
3. `unconfirmed` lists numbers found in the story that named no single record: a curator may want to know.
4. Read the `unmatched` list and pass it to the collection's curator if useful (for example, stories whose object has no record yet).

### Hold a story back

Add its address to `hold` in `config/collection_story_sources.yml`, with the reason, and harvest again. A held story goes to the
curator list (reason `held`) and is never shown. Do not edit `config/collection_stories.yml` by hand: the next harvest would undo it.

## Add a source

Add a site only when its stories can be matched **the same exact way**: an accession number in the story's image file names,
captions or text, for records of one collection in the index.

1. Add an entry to `config/collection_story_sources.yml`: `name` (shown on the cards), `collection` (the `collection_ssim` value, as in
   `config/pages.yml`), `index_url` (the page listing the stories), `story_prefix` (every story's address starts with it).
2. Check that the site's pages give `og:title`, `og:image`, `og:description` or an `.article` / `main` with an h1 and paragraphs
   (`CollectionStories::Page`). A site built differently needs a test page in `test/models/collection_stories/page_test.rb` first.
3. Harvest, review, commit, and open a pull request listing which stories matched which records.

## Museums Victoria stories

Museums Victoria has published 19 stories about objects connected with the University (CSIRAC, MUDPAC, the Engineering School,
the Sigalas family papers, student badges, the Henbury meteorite and others). Those objects and stories are ordinary harvested
records in the Engineering and Information Technology Collection (`data/harvested.csv`, source "Museums Victoria Collections").
Each story is also listed in `config/collection_stories_museums_victoria.yml`, with the registration numbers of the objects it is
about, so those objects' record pages show it under "Stories from the collection". `CollectionStories.default` reads this file
and `config/collection_stories.yml` together; it is kept apart so a Grainger harvest never overwrites it.

Both files are written by `python3 scripts/museums-victoria/build_harvested_rows.py --stories <unimelb_related_stories.json>`
(the fetcher's output; see `docs/handover-collection-stories.md`). Then run `bin/rails collections:index_harvested`. The API
rate-limits: the script stops on a 429 and must not be made to retry around it. Licences were cleared with Museums Victoria by
the site owner; every story is CC BY 4.0.

## Tests

`test/models/collection_stories_test.rb` (matching, the committed file), `test/models/collection_stories/*` (page reading, candidates,
harvest), `test/components/nexus_ccs/collection_stories_component_test.rb` (the section) and
`test/integration/record_collection_stories_test.rb` (the record page; needs Solr).
