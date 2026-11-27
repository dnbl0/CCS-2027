#!/usr/bin/env python3
"""Fetch Museums Victoria stories (articles) linked to collection objects connected to the University of Melbourne.

Museums Victoria Collections API: https://collections.museumsvictoria.com.au/developers
(the API lives on collections.museumsvictoria.com.au; museumsvictoria.com.au/api refuses requests).

Steps
1. Search items and specimens for the exact phrases "University of Melbourne" and "Melbourne University", every page.
2. Keep only records genuinely connected to the University: the name appears in an ownership or association field
   (associations, collection names, acquisition information, acknowledgement, credit line, lender). A record that only
   mentions the University in its description or keywords is set aside as "mention only", with the field it was found in.
3. Collect the unique story ids (relatedArticleIds) of the connected records, with which objects link to each story.
4. Fetch the stories in batches (GET /api/search?id=articles/1,articles/2,...), then their parent and child articles,
   so multi-part stories are complete.
5. Write unimelb_related_stories.json, plus a Markdown and a CSV summary.

Standard library only. Usage:  python3 fetch_unimelb_stories.py [--out DIR]
"""

import argparse
import csv
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://collections.museumsvictoria.com.au/api"
USER_AGENT = "UniMelbStoriesFetcher/1.0"  # the API rejects requests without a User-Agent
PHRASES = ['"University of Melbourne"', '"Melbourne University"']
RECORD_TYPES = ["item", "specimen"]
PER_PAGE = 100
BATCH = 40           # article ids per request
PAUSE = 0.2          # seconds between requests
RETRIES = 4

UNIVERSITY = re.compile(r"\b(university of melbourne|melbourne university|univ(?:ersity|\.)? of melb(?:ourne|\.)?)\b", re.I)

# Fields that say who owns, lent, gave or is associated with the object. A match here is a genuine connection.
CONNECTION_FIELDS = ["associations", "collectionNames", "acquisitionInformation", "acknowledgement", "creditLine", "lender",
                     "ownership", "provenance"]


def get(path, params):
    """GET a JSON endpoint with polite pacing and retries. Returns (data, headers)."""
    url = f"{API}/{path}?{urllib.parse.urlencode(params, safe=',/')}"
    for attempt in range(RETRIES + 1):
        time.sleep(PAUSE)
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response), response.headers
        except urllib.error.HTTPError as error:
            if error.code not in (429, 500, 502, 503, 504) or attempt == RETRIES:
                raise
        except (urllib.error.URLError, TimeoutError):
            if attempt == RETRIES:
                raise
        wait = 2 ** attempt
        print(f"  retrying in {wait}s: {url}", file=sys.stderr)
        time.sleep(wait)


def search_all(phrase, record_type):
    """Every record of one type matching one phrase, following Total-Pages."""
    records, page, pages = [], 1, 1
    while page <= pages:
        data, headers = get("search", {"query": phrase, "recordtype": record_type, "perpage": PER_PAGE, "page": page})
        records.extend(data)
        pages = int(headers.get("Total-Pages") or 1)
        page += 1
    return records


def mentions(value, path=""):
    """(field path, text) for every string in value that names the University."""
    if isinstance(value, dict):
        for key, inner in value.items():
            yield from mentions(inner, f"{path}.{key}" if path else key)
    elif isinstance(value, list):
        for inner in value:
            yield from mentions(inner, path)
    elif isinstance(value, str) and UNIVERSITY.search(value):
        yield path, value.strip()


def connection(record):
    """'connected' with the evidence, 'mention only' with where it was found, or None when the University is not named at all."""
    found = list(mentions(record))
    strong = [(path, text) for path, text in found if path.split(".")[0] in CONNECTION_FIELDS]
    if strong:
        return "connected", strong
    if found:
        return "mention only", found
    return None, []


def fetch_articles(ids):
    """Full article records for the ids, in batches; then any parent or child articles not yet fetched."""
    articles, wanted = {}, list(dict.fromkeys(ids))
    while wanted:
        batch, wanted = wanted[:BATCH], wanted[BATCH:]
        data, _ = get("search", {"id": ",".join(batch)})
        for article in data:
            articles[article["id"]] = article
        related = set()
        for article in data:
            if article.get("parentArticleId"):
                related.add(article["parentArticleId"])
            related.update(article.get("childArticleIds") or [])
        wanted.extend(sorted(related - set(articles) - set(wanted)))
    return articles


def summary_object(record, evidence):
    return {
        "id": record["id"],
        "displayTitle": record.get("displayTitle"),
        "registrationNumber": record.get("registrationNumber"),
        "url": f"https://collections.museumsvictoria.com.au/{record['id']}",
        "evidence": [{"field": field, "text": text[:300]} for field, text in evidence],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=".", help="folder for the output files")
    out = Path(parser.parse_args().out)
    out.mkdir(parents=True, exist_ok=True)

    records = {}
    for phrase in PHRASES:
        for record_type in RECORD_TYPES:
            found = search_all(phrase, record_type)
            print(f"search {phrase} {record_type}s: {len(found)}")
            for record in found:
                records[record["id"]] = record

    connected, mention_only = {}, {}
    for record in records.values():
        kind, evidence = connection(record)
        if kind == "connected":
            connected[record["id"]] = summary_object(record, evidence)
        elif kind == "mention only":
            mention_only[record["id"]] = summary_object(record, evidence) | {"relatedArticleIds": record.get("relatedArticleIds") or []}

    links = {}  # article id -> connected objects that link to it
    for record_id, summary in connected.items():
        for article_id in records[record_id].get("relatedArticleIds") or []:
            links.setdefault(article_id, []).append({"id": summary["id"], "displayTitle": summary["displayTitle"]})

    articles = fetch_articles(sorted(links)) if links else {}
    stories = []
    for article_id, article in sorted(articles.items()):
        stories.append({
            "id": article_id,
            "url": f"https://collections.museumsvictoria.com.au/{article_id}",
            "displayTitle": article.get("displayTitle"),
            "contentSummary": article.get("contentSummary"),
            "content": article.get("content"),
            "authors": article.get("authors"),
            "media": article.get("media"),
            "parentArticleId": article.get("parentArticleId"),
            "childArticleIds": article.get("childArticleIds"),
            "licence": article.get("licence"),
            "linkedUniversityObjects": links.get(article_id, []),
            "fetchedAsPartOf": None if article_id in links else "parent or child of a linked story",
        })

    result = {
        "source": API,
        "fetched": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "searched": {"phrases": PHRASES, "recordTypes": RECORD_TYPES, "recordsFound": len(records)},
        "connectedObjects": sorted(connected.values(), key=lambda o: o["id"]),
        "mentionOnlyObjects": sorted(mention_only.values(), key=lambda o: o["id"]),
        "stories": stories,
    }
    (out / "unimelb_related_stories.json").write_text(json.dumps(result, indent=2, ensure_ascii=False))

    with open(out / "unimelb_related_stories.csv", "w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file)
        writer.writerow(["story id", "story title", "story url", "linked University object ids", "linked University object titles"])
        for story in stories:
            linked = story["linkedUniversityObjects"]
            writer.writerow([story["id"], story["displayTitle"], story["url"], "; ".join(o["id"] for o in linked),
                             "; ".join(o["displayTitle"] or "" for o in linked)])

    lines = ["# Museums Victoria stories linked to University of Melbourne objects", "",
             f"Fetched {result['fetched']} from {API}.", "",
             f"Records naming the University: {len(records)}. Genuinely connected: {len(connected)}. "
             f"Mention only (set aside): {len(mention_only)}. Stories linked to connected objects: {len(links)} "
             f"({len(stories)} with parent/child parts).", "", "## Connected objects", ""]
    for obj in result["connectedObjects"]:
        lines.append(f"- [{obj['displayTitle']}]({obj['url']}): {obj['evidence'][0]['field']}: {obj['evidence'][0]['text'][:120]}")
    lines += ["", "## Stories", ""]
    for story in stories:
        linked = ", ".join(o["displayTitle"] or o["id"] for o in story["linkedUniversityObjects"]) or story["fetchedAsPartOf"]
        lines.append(f"- [{story['displayTitle']}]({story['url']}): linked from {linked}")
    lines += ["", "## Mention only (not used)", ""]
    for obj in result["mentionOnlyObjects"]:
        lines.append(f"- [{obj['displayTitle']}]({obj['url']}): {obj['evidence'][0]['field']}"
                     f" ({len(obj['relatedArticleIds'])} stories)")
    (out / "unimelb_related_stories.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"connected objects: {len(connected)}; mention only: {len(mention_only)}; stories: {len(stories)}")
    print(f"wrote {out / 'unimelb_related_stories.json'} (+ .md, .csv)")


if __name__ == "__main__":
    main()
