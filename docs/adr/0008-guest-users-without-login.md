# Visitors do not log in: a guest row keyed by the session cookie

Searching, saving records, lists and saved searches work without an account. Blacklight's guest-user support gives each visitor
a `User` row found through the session cookie (`_ccs_session`, kept 30 days, `config/initializers/session_store.rb`). Two
differences from the gem's default (`GuestBookmarks`): browsing never writes a row, so crawlers and first visits leave nothing;
the row is created when the visitor first saves something. The sensitivity choice is kept in the cookie only, not the
database. No personal details are collected except on an access request, which the visitor types in themselves.

## Consequences

A visitor's saved items belong to one browser: clearing cookies or changing device loses them, and the pages say so ("on this
device"). There is nothing to attack by credential, and no password or email to store. Anything that needs to know who a person
is (an admin screen for access requests, sharing a list between people) needs a real sign-in, which is a new decision. The
personal pages are `noindex, nofollow` and 404 while `SAVED_RECORDS` is off ([ADR 0005](0005-saved-records-hidden-by-default.md)).
