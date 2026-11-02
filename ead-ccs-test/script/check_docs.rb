#!/usr/bin/env ruby
# Checks that the documentation still matches the code, with no gem. Run: ruby script/check_docs.rb (bin/ci runs it)
#
#   1. every environment variable the code reads is in docs/configuration.md
#   2. every relative link in the current docs points at a file that exists
#   3. every `bin/...` command and `rails task:name` the docs and README quote exists (Rails tasks are read from `bin/rails -AT`)
#
# It reads the quick start in README.md and docs/running-the-app.md as well, so a renamed script or task cannot leave the first
# page a new developer reads pointing at nothing. Exit status 1 on any problem.
require "pathname"

APP = Pathname.new(File.expand_path("..", __dir__))
REPO = APP.parent
problems = []

# 1. Environment variables ---------------------------------------------------------------------------------------------------------
IGNORED = %w[RAILS_ENV BUNDLE_GEMFILE BUNDLE_WITHOUT HOME TMPDIR SECRET_KEY_BASE_DUMMY].freeze
code = Dir[APP.join("{app,lib,config}/**/*.{rb,yml,erb,rake}").to_s, APP.join("bin/*").to_s].reject { |f| File.directory?(f) }
names = code.flat_map do |file|
  body = File.readlines(file).reject { |line| line.lstrip.start_with?("#") }.join # a commented-out example is not a read
  body.scan(/ENV(?:\[|\.fetch\(|\.key\?\()\s*["']([A-Z][A-Z0-9_]+)["']/).flatten +
    body.scan(/\b(?:on\?|list)\(\s*["']([A-Z][A-Z0-9_]+)["']/).flatten
end
names += %w[SEARCH RECORD DOWNLOAD ASSET].map { |kind| "RATE_LIMIT_#{kind}_PER_MINUTE" } # built as RATE_LIMIT_#{kind}_PER_MINUTE in BotGuard
names = (names.uniq - IGNORED).sort
documented = File.read(REPO.join("docs/configuration.md")).scan(/^\| `([A-Z][A-Z0-9_]+)` \|/).flatten
(names - documented).each { |name| problems << "docs/configuration.md does not list the environment variable #{name}" }
(documented - names - %w[AUTO_INDEX SOLR_MODULES SECRET_KEY_BASE WEB_CONCURRENCY]).each { |name| problems << "docs/configuration.md lists #{name}, which no code reads (remove it, or add it to this script's exceptions)" }

# 2 and 3. Links, commands and tasks ----------------------------------------------------------------------------------------------------
docs = Dir[REPO.join("{README,CONTEXT,CONTRIBUTING}.md").to_s, REPO.join("docs/*.md").to_s, REPO.join("docs/adr/*.md").to_s,
           APP.join("README.md").to_s, APP.join("docs/*.md").to_s].sort
HISTORICAL = %w[figma-library-audit-2026-10-12.md responsive-audit-2026-11.md HANDOFF.md code-quality-plan.md css-refactor.md conventions.md].freeze
docs.reject! { |f| HISTORICAL.include?(File.basename(f)) }

tasks = nil
docs.each do |file|
  rel = Pathname.new(file).relative_path_from(REPO).to_s
  text = File.read(file)
  text.scan(/\]\(([^)\s]+)\)/).flatten.each do |target|
    next if target.start_with?("http", "mailto:", "#")

    path = target.split("#").first
    problems << "#{rel}: link to #{target} does not exist" unless File.exist?(File.expand_path(path, File.dirname(file)))
  end
  # Commands in code spans and blocks: bin/name (in ead-ccs-test), and `rails a:b` / `bin/rails a:b`
  text.scan(%r{(?<![\w/.-])bin/([a-z][\w-]*)}).flatten.uniq.each do |bin|
    next if %w[rails solr].include?(bin) || # solr is Solr's own script, not ours
            File.exist?(APP.join("bin", bin)) || File.exist?(REPO.join("bin", bin))

    problems << "#{rel}: mentions bin/#{bin}, which does not exist" unless text.include?("bin/#{bin}/") # a directory path, not a command
  end
  text.scan(/(?:bin\/)?rails ([a-z_]+:[a-z_:]+)/).flatten.uniq.each do |task|
    tasks ||= Dir.chdir(APP) { `bin/rails -AT 2>/dev/null`.scan(/rails ([a-z_:]+)/).flatten }
    problems << "#{rel}: mentions rails #{task}, which is not a task" unless tasks.include?(task) || tasks.any? { |t| t.start_with?("#{task}:") }
  end
end

puts "#{names.size} environment variables, #{docs.size} documents checked"
problems.each { |problem| puts "PROBLEM  #{problem}" }
puts "ok" if problems.empty?
exit(problems.empty? ? 0 : 1)
