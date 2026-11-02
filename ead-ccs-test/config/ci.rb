# Run using bin/ci. The same checks as .github/workflows/rails-ci.yml, so a branch that passes here passes there, plus the locale check
# (script/i18n_check.rb). See CONTRIBUTING.md.
#
#   bin/ci               style, security audits, locale check and the unit suite with Solr (if it answers) and without it
#   bin/ci --system      also the browser and accessibility tests (need Solr with the records indexed, Chrome and axe-core: see
#                        docs/running-the-app.md); run one at a time (PARALLEL_WORKERS=1)
#   bin/ci --quick       style and tests only (skips the audits, which fetch their advisory data from the network)
#
# Set SOLR_URL as for development. In a second worktree set DB_SUFFIX too, so its databases do not collide with the first one's.
require "net/http"

system_tests = ARGV.include?("--system")
quick = ARGV.include?("--quick")
solr_url = ENV.fetch("SOLR_URL", "http://127.0.0.1:8983/solr/blacklight-core")

solr_up = begin
  Net::HTTP.get_response(URI("#{solr_url}/select?q=*:*&rows=0")).is_a?(Net::HTTPSuccess)
rescue StandardError
  false
end

CI.run do
  step "Database", "env RAILS_ENV=test bin/rails db:prepare"

  step "Style: Ruby", "bin/rubocop"
  step "Style: ERB", "bin/erb_lint --lint-all"
  step "Locale strings: none missing, none unused", "ruby script/i18n_check.rb"
  step "Docs: links, commands and environment variables match the code", "ruby script/check_docs.rb"

  unless quick
    step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
    step "Security: Gem audit", "bin/bundler-audit"
    step "Security: Importmap vulnerability audit", "bin/importmap audit"
  end

  # What the "rails" job of GitHub CI does: no Solr, so every test that reads Solr skips itself (needs_solr in test/test_helper.rb)
  step "Tests: without Solr (as in GitHub CI)", "env SOLR_URL=http://127.0.0.1:9/solr/none bin/rails test"

  if solr_up
    step "Tests: with Solr at #{solr_url}", "bin/rails test"
  else
    echo "Tests: with Solr skipped, nothing answers at #{solr_url}. Start Solr to run the tests that read it.", type: :error
  end

  if system_tests
    if solr_up
      step "Tests: system (browser journeys and accessibility)", "env PARALLEL_WORKERS=1 bin/rails test:system"
    else
      failure "System tests need Solr", "Nothing answers at #{solr_url}."
      results << false
    end
  end
end
