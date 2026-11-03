# Galleries, embeds and oEmbed

A visitor's list can be shared as a **gallery** by an unguessable link, and a record or gallery can be **embedded** in another
site. Ideas came from Europeana's public portal (sets with a description and cover, a set-card group, a publish control) and
Google Arts & Culture (shareable galleries); no code was copied (EUPL). Europeana publishes through moderation; this site does
not: a gallery is link-only, never listed.

| URL | What |
| --- | --- |
| `POST /lists/:list_id/share`, `/share/regenerate`, `DELETE /lists/:list_id/share` | The owner shares, replaces the link, or stops |
| `GET /galleries/:token` | Read-only gallery (cards, Copy link, Cite, Share and embed, Add to my list); `/citations`, `POST /copy` |
| `GET /embed/records/:id`, `/embed/galleries/:token` | Framable cards (no script, no cookie) |
| `GET /oembed?url=...&format=json` | oEmbed 1.0 (rich) for `/catalog/:id` and `/galleries/:token`; record pages carry the discovery `<link>` |

Privacy: 32-character token (192 random bits), stored on `lists.share_token`; a malformed token is rejected before the database;
wrong and revoked tokens are the same 404; no owner appears anywhere; `Referrer-Policy: same-origin` on the gallery; not
cacheable publicly; noindex, nofollow and Disallow in robots.txt; galleries follow `SAVED_RECORDS`. Images follow `SharedMedia`
(AccessPolicy and Sensitivity; a viewer's own "view" choice is deliberately not honoured). Only `/embed/*` drops
X-Frame-Options and sends an enforced `frame-ancestors` (`EMBED_FRAME_ANCESTORS`). The token is in request paths, so server logs
hold live links: treat logs as sensitive.
