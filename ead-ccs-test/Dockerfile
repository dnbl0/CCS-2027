# syntax=docker/dockerfile:1

# 1. Blacklight Rails Server
FROM ruby:4.0.6-trixie AS ead-ccs

## System dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      curl \
      libpq-dev \
      libvips42 \
      shared-mime-info \
    && rm -rf /var/lib/apt/lists/*

## Non-root user (keep your existing UID/GID)
RUN groupadd -g 258995 app && \
    useradd -u 258995 -g 258995 -m -s /bin/bash app

WORKDIR /app

## Install gems first (better layer caching)
COPY Gemfile Gemfile.lock ./
ENV BUNDLE_WITHOUT="development test"
RUN bundle install --jobs 4 --retry 3 && \
    rm -rf "$(gem env gemdir)"/cache/*.gem

## Copy application code
COPY . .

## Precompile assets
ENV RAILS_ENV=production 
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

## UniMelb host allow-list configured in /config/environments/production.rb

## Ownership
RUN sh -c 'chmod +x /app/bin/*' && chown -R app:app /app
USER app

EXPOSE 3000

ENTRYPOINT ["/app/bin/docker-entrypoint.sh"]

## Simple start (TODO: move migrations/seeds to an init container)
## exec: the server replaces the shell, so Puma is the process that receives SIGTERM and drains in-flight requests before it stops (CCS-146)
## AUTO_INDEX=true also fills an empty Solr core in the background (for hosts where Solr has no persistent disk)
CMD ["bash", "-lc", "bundle exec rails db:prepare && { [ \"$AUTO_INDEX\" = true ] && bin/index-when-ready & } && exec bundle exec rails server -b 0.0.0.0"]

# Image 2. Apache Solr
FROM solr:10.0 AS solr
ENV SOLR_MODULES=analysis-extras
COPY solr/security.json /opt/solr/server/solr/
COPY solr/conf /opt/solr/server/solr/configsets/blacklight-conf

CMD ["solr-precreate", "blacklight-core", "/opt/solr/server/solr/configsets/blacklight-conf"]
