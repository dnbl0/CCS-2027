# Running the Rails app

This guide gets the Cultural Collections Search Rails app (`ead-ccs-test/`) running on your own computer, then points
to how it runs on Azure. It assumes a Mac with [Homebrew](https://brew.sh). Run every command in the Terminal app.

The app has three moving parts, and all three must be running:

| Part | What it does | Where it runs |
|---|---|---|
| The Rails app | The website | http://localhost:3002 |
| PostgreSQL | Small database for the app's own tables (saved records, sessions) | port 5432 |
| Solr | The search index of the 40,962 collection records | http://localhost:8984 |

> **Ports.** `3000` is the static prototype site, and `8983` belongs to another project's Solr: never stop or reuse
> it. This app uses `3002` and `8984`.

## 1. One-time setup

1. **Install the tools** (skip any you already have):

   ```sh
   brew install rbenv ruby-build postgresql@17 node openjdk
   brew services start postgresql@17
   ```

   Add `eval "$(rbenv init - zsh)"` to `~/.zshrc`, then open a new Terminal window. Java (`openjdk`) is for Solr.

2. **Get the code and install Ruby 4.0.6** (the version in `.ruby-version`):

   ```sh
   git clone https://github.com/dnbl0/CCS-2027.git
   cd CCS-2027/ead-ccs-test
   rbenv install 4.0.6        # about 5 minutes the first time
   gem install bundler
   bundle install
   ```

3. **Create the database:**

   ```sh
   bin/rails db:prepare
   ```

4. **Start Solr and fill it with the records** (the CSV exports are in `data/`):

   ```sh
   bundle exec solr_wrapper -p 8984        # leave this window open; the first run downloads Solr
   ```

   In a **second** Terminal window:

   ```sh
   cd CCS-2027/ead-ccs-test
   export SOLR_URL=http://127.0.0.1:8984/solr/blacklight-core
   bin/rails collections:index             # about 20 seconds for ~41,000 records
   ```

## 2. Every day: start the app

Solr and PostgreSQL must be running (PostgreSQL starts with `brew services start postgresql@17`; Solr with the
`solr_wrapper` command above). Then, from `ead-ccs-test/`:

```sh
export SOLR_URL=http://127.0.0.1:8984/solr/blacklight-core
bin/dev            # the app on http://localhost:3002 plus the stylesheet builder
```

Open **http://localhost:3002**. Search lives at http://localhost:3002/catalog. Stop it with `Ctrl-C`.
`bin/dev` runs two things from `Procfile.dev`: the web server and `dartsass:watch`, which rebuilds the Bootstrap
stylesheet when you change it. To run only the server: `bin/rails server -p 3002`.

The first load shows a navy "Loading Cultural Collections Search" screen until the page has finished loading.

## 3. Check it works

```sh
bin/rails test                  # the app's tests; no Solr needed (about 3 seconds)
bundle exec rubocop             # code style
```

Browser tests (`bin/rails test:system`) need Solr indexed at `SOLR_URL` and Chrome; see [solr-dev.md](solr-dev.md).

## 4. Where things are

| To change | Look in |
|---|---|
| The filter sidebar | `app/components/nexus_ccs/filter_sidebar_component.*` (facets are Blacklight's own), `app/assets/stylesheets/components/filter_drawer.css` |
| The results page layout | `app/assets/stylesheets/components/results_layout.css` |
| The page loading screen | `app/assets/stylesheets/components/page_loader.css`, `app/javascript/page_loader.js` |
| Facets and fields | `app/controllers/catalog_controller.rb`, `config/data_model/` |
| The content pages (home, help...) | `app/views/pages`, `config/pages.yml`; their styles are generated from the static site (see the [README](../README.md)) |

## 5. Troubleshooting

| What you see | What to do |
|---|---|
| "Search is unavailable" or a 503 on `/catalog` | Solr is not running or `SOLR_URL` is not set in this window. Start `solr_wrapper` and `export SOLR_URL=...` again. |
| Search works but shows 0 results | The index is empty: run `bin/rails collections:index` (add `FORCE=1` to reindex). |
| `PG::ConnectionBad` | PostgreSQL is not running: `brew services start postgresql@17`. |
| `Address already in use` on 3002 | Another copy is running. Find it with `lsof -nP -iTCP:3002 -sTCP:LISTEN`, and stop that one by its process id. |
| The page looks unstyled | Run `bin/rails dartsass:build` (or use `bin/dev`, which watches). |
| Gems or Ruby version errors | `rbenv install 4.0.6` then `bundle install`. |

## 6. On Azure

The live copy runs on Azure Container Apps. How to deploy and redeploy it, and the gotchas of that setup, are in
[infra/azure/README.md](../../infra/azure/README.md) and the header of
[infra/azure/containerapps.sh](../../infra/azure/containerapps.sh). Never put passwords in the repository.
