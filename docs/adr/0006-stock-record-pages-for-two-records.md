# Stock record pages exist for two records, for comparison

**Superseded 27 Nov 2026.** The owner, Dean Noble, asked for the pages to be removed. They are gone; an old `/stock/:id` or
`/branded-stock/:id` address now moves permanently (301) to `/catalog/:id`.

`/stock/:id` (Blacklight's own record page) and `/branded-stock/:id` (the same page in the University header and footer) are shown
to stakeholders for `emu-9044` and `vernon-MHM00394` only; any other id is a 404 (`StockRecords`). They let the site's own record
page be compared with Blacklight's default. Every deploy keeps them and leaves `/catalog/:id` unchanged.

## Consequences

They are a second record page (two controllers, nine components, two layouts and their own styles). When the comparison is
finished, either delete them or make the chosen design the only record page.
