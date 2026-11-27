#!/usr/bin/env python3
"""Add the Museums Victoria stories about University of Melbourne objects, and those objects, to ead-ccs-test/data/harvested.csv.

Input: unimelb_related_stories.json, written by fetch_unimelb_stories.py (full story text, so stories are not fetched again).
Only the objects need the API: they are fetched in one or two batched requests (GET /api/search?id=items/1,items/2,...).

Rows added (all filed under the Engineering and Information Technology Collection, as agreed with the site owner):
  * every story the fetcher linked to a University object (19 in the 26 Nov run), and all its parent/child parts, and
  * the objects those stories are linked to.

It also writes ead-ccs-test/config/collection_stories_museums_victoria.yml: each story with the registration numbers of the objects
it is about, so their record pages show it under "Stories from the collection" (CollectionStories, docs/collection-stories.md).

Re-running replaces these rows (matched on id) and leaves every other row alone. Then: bin/rails collections:index_harvested.
If the API answers 429 the script stops and says when to try again; it never retries around a rate limit.

Usage:  python3 build_harvested_rows.py --stories unimelb_related_stories.json [--harvested ../../ead-ccs-test/data/harvested.csv]
"""

import argparse
import csv
import html
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://collections.museumsvictoria.com.au/api"
SITE = "https://collections.museumsvictoria.com.au"
USER_AGENT = "UniMelbStoriesFetcher/1.0"
COLLECTION = "Engineering and Information Technology Collection"
SOURCE = "Museums Victoria Collections"
PAUSE = 1.0
BATCH = 40
COLUMNS = ["collection", "source", "id", "title", "description", "keywords", "registration_number", "date", "maker_or_collector",
           "place", "classification", "sub_collection", "image_url", "image_alt", "record_url", "file_name", "file_format"]


def fetch_items(ids):
    """Full item records, in batches. Stops on a rate limit instead of retrying."""
    items = {}
    for start in range(0, len(ids), BATCH):
        url = f"{API}/search?{urllib.parse.urlencode({'id': ','.join(ids[start:start + BATCH]), 'perpage': 100}, safe=',/')}"
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
        time.sleep(PAUSE)
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                for record in json.load(response):
                    items[record["id"]] = record
        except urllib.error.HTTPError as error:
            if error.code == 429:
                sys.exit(f"Rate limited (429). Try again after {error.headers.get('Retry-After', 'a while')} seconds.")
            raise
    return items


def text(value):
    """Plain text from API HTML."""
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", value or ""))).strip()


def first_sentences(value, limit=600):
    value = text(value)
    if len(value) <= limit:
        return value
    cut = value[:limit]
    end = max(cut.rfind(". "), cut.rfind("? "), cut.rfind("! "))
    return cut[:end + 1] if end > limit // 2 else cut.rsplit(" ", 1)[0] + "…"


def image(record):
    """Medium image uri and its alt text from the first image in the record's media."""
    for media in record.get("media") or []:
        if media.get("type") == "image":
            picture = media.get("medium") or media.get("small") or media.get("large") or {}
            if picture.get("uri", "").startswith("https://"):
                return picture["uri"], media.get("alternativeText") or ""
    return "", ""


def story_row(story):
    uri, alt = image(story)
    authors = "; ".join(a["fullName"] for a in story.get("authors") or [] if a.get("fullName"))
    return {
        "collection": COLLECTION, "source": SOURCE, "id": story["id"], "title": text(story["displayTitle"]),
        "description": first_sentences(story.get("contentSummary") or story.get("content")),
        "maker_or_collector": authors, "classification": "Story", "image_url": uri, "image_alt": alt, "record_url": f"{SITE}/{story['id']}",
    }


def stories_yaml(direct, items):
    """The record pages' data file. JSON strings are valid YAML scalars, so json.dumps quotes every value safely."""
    lines = ["# Museums Victoria stories about University of Melbourne objects (CollectionStories, docs/collection-stories.md).",
             "# Written by scripts/museums-victoria/build_harvested_rows.py; review the diff before committing, do not edit by hand.",
             "# A story shows on a record whose accession number (the object's registration number) AND collection match.",
             "stories:"]
    for story in direct:
        numbers = sorted({items[o["id"]].get("registrationNumber") for o in story["linkedUniversityObjects"]} - {None, ""})
        if not numbers:
            continue
        uri, _alt = image(story)
        entry = {"title": text(story["displayTitle"]), "url": f"{SITE}/{story['id']}", "image_url": uri,
                 "summary": first_sentences(story.get("contentSummary") or story.get("content"), 200),
                 "site": "Museums Victoria", "collection": COLLECTION}
        lines.append(f"- title: {json.dumps(entry['title'], ensure_ascii=False)}")
        lines += [f"  {key}: {json.dumps(value, ensure_ascii=False)}" for key, value in entry.items() if key != "title"]
        lines.append("  accession_numbers:")
        lines += [f"  - {json.dumps(number, ensure_ascii=False)}" for number in numbers]
    return "\n".join(lines) + "\n"


def names(values, key="name"):
    return [v[key] if isinstance(v, dict) else v for v in values or [] if v]


def item_row(record):
    uri, alt = image(record)
    description = record.get("objectSummary") or record.get("physicalDescription") or record.get("summary") or record.get("longDescription")
    makers = [a.get("name") for a in record.get("associations") or [] if a.get("type") == "Maker" and a.get("name")]
    return {
        "collection": COLLECTION, "source": SOURCE, "id": record["id"], "title": text(record["displayTitle"]),
        "description": first_sentences(description), "keywords": ", ".join(k.replace(",", "") for k in record.get("keywords") or []),
        "registration_number": record.get("registrationNumber") or "", "date": next((a["date"] for a in record.get("associations") or [] if a.get("date")), ""),
        "maker_or_collector": "; ".join(makers), "classification": " > ".join(names(record.get("classifications"))) or record.get("objectName") or "",
        "sub_collection": "CSIRAC" if "CSIRAC" in text(record["displayTitle"]) else "", "image_url": uri, "image_alt": alt,
        "record_url": f"{SITE}/{record['id']}",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--stories", required=True, help="unimelb_related_stories.json from fetch_unimelb_stories.py")
    parser.add_argument("--harvested", default=str(Path(__file__).resolve().parents[2] / "ead-ccs-test/data/harvested.csv"))
    parser.add_argument("--stories-file", default=str(Path(__file__).resolve().parents[2] / "ead-ccs-test/config/collection_stories_museums_victoria.yml"))
    parser.add_argument("--items-cache", help="read/write the fetched items here so a re-run does not call the API")
    args = parser.parse_args()

    stories = {s["id"]: s for s in json.load(open(args.stories))["stories"]}
    direct = [s for s in stories.values() if s["linkedUniversityObjects"]]
    chosen = direct + [s for s in stories.values() if s["fetchedAsPartOf"]]
    object_ids = sorted({o["id"] for s in direct for o in s["linkedUniversityObjects"]})

    cache = Path(args.items_cache) if args.items_cache else None
    if cache and cache.exists():
        items = json.load(open(cache))
    else:
        items = fetch_items(object_ids)
        if cache:
            cache.write_text(json.dumps(items, indent=2, ensure_ascii=False))
    missing = [i for i in object_ids if i not in items]
    if missing:
        sys.exit(f"API did not return: {', '.join(missing)}")

    new_rows = [story_row(s) for s in chosen] + [item_row(items[i]) for i in object_ids]
    new_ids = {r["id"] for r in new_rows}

    with open(args.harvested, newline="", encoding="utf-8") as file:
        kept = [r for r in csv.DictReader(file) if not (r["source"] == SOURCE and r["id"] in new_ids)]
    with open(args.harvested, "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=COLUMNS, lineterminator="\r\n")
        writer.writeheader()
        writer.writerows(kept)
        writer.writerows({c: row.get(c, "") for c in COLUMNS} for row in new_rows)
    Path(args.stories_file).write_text(stories_yaml(sorted(direct, key=lambda s: text(s["displayTitle"])), items), encoding="utf-8")
    print(f"{len(chosen)} stories and {len(object_ids)} objects written to {args.harvested}")


if __name__ == "__main__":
    main()
