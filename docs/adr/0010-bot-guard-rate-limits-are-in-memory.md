# Rate limits are counted in memory, per process

`BotGuard` (Rack middleware in `lib/middleware`) answers 429 with `Retry-After` when one IP address passes the limit for its
kind of request in a minute: search 120, record 240, download 20, asset 600, each set by an environment variable
(`docs/configuration.md`). The counts live in a table inside the Puma process (`RATE_LIMIT_STORE=memory`, the default),
because the app runs as one small container and needs nothing else to run: no Redis, no shared cache. `RATE_LIMIT_STORE=cache`
counts in `Rails.cache` instead. The same middleware turns away listed crawlers (403) and sets `X-Robots-Tag`.

## Consequences

The limit is per process, and a restart resets it, so with several processes or instances the real limit is the limit times
their number. That is acceptable for its purpose, which is to stop one scraper hammering a small deployment, not to be an exact
quota. An exact limit belongs in front of the app (a CDN or WAF) or needs a shared cache store. Behind a proxy `remote_ip`
must be the visitor's address, not the proxy's. Tested in `test/integration/bot_guard_test.rb`.
