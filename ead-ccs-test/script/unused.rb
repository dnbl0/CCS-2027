#!/usr/bin/env ruby
# Finds code nothing refers to, by searching for its name: a report of CANDIDATES, not a verdict. Run: ruby script/unused.rb
#
#   stylesheets          CSS/SCSS files no manifest @imports and nothing links
#   stimulus controllers app/javascript/controllers/*_controller.js no template, component or helper attaches
#   partials             app/views/**/_name.html.erb nothing renders (Blacklight itself renders some it lets us override)
#   components           ViewComponent classes nothing instantiates
#   models and helpers   classes, modules and helper methods no other file mentions
#   images               app/assets/images files nothing mentions
#   routes               named routes whose _path / _url helper nothing calls (the route may still be a URL people visit)
#   locale strings       see script/i18n_check.rb
#
# A name built at run time ("icon_#{name}.svg") cannot be found by searching, so read each candidate before deleting it.
# What the 2026-style CSS in this app means by "unused" is also judged by hand: a stylesheet can be imported and still match nothing.
# See docs/maintainability.md for the last run, and how each candidate was checked.
require "pathname"

ROOT = Pathname.new(File.expand_path("..", __dir__))
Dir.chdir(ROOT)

def read_all(globs)
  Dir[*globs].select { |f| File.file?(f) }.to_h { |f| [ f, File.read(f, mode: "rb").force_encoding("UTF-8").scrub ] }
end

CODE = read_all(%w[app/**/*.{rb,erb,js,css,scss,yml} lib/**/*.{rb,rake} config/**/*.{rb,yml} test/**/*.rb bin/* Dockerfile]).reject { |f, _| f.start_with?("app/assets/builds/") }.freeze
APP = CODE.reject { |f, _| f.start_with?("test/") }.freeze

def mentions(name, files, except: [])
  files.any? { |f, body| !except.include?(f) && body.match?(/(?<![\w])#{Regexp.escape(name)}(?![\w])/) }
end

def report(title, items)
  puts "\n== #{title}: #{items.empty? ? 'none' : items.size}"
  items.each { |item| puts "  #{item}" }
end

# 1. Stylesheets: referenced by an @import (css or scss) or named in any file other than itself
sheets = Dir["app/assets/stylesheets/**/*.{css,scss}"].reject { |f| f.include?("/builds/") }
imports = CODE.select { |f, _| f.end_with?(".css", ".scss") }.values.join("\n")
report "stylesheets nothing imports", sheets.reject { |f|
  rel = f.delete_prefix("app/assets/stylesheets/")
  base = rel.sub(/\.(css|scss)\z/, "").sub(%r{(\A|/)_}, '\1')
  imports.include?(rel) || imports.match?(/@(import|use)[^;\n]*["'\/]#{Regexp.escape(base)}(\.css|\.scss)?["')]/) ||
    mentions(rel, APP, except: [ f ]) || mentions(File.basename(f), APP, except: [ f ])
}

# 2. Stimulus controllers: the identifier is the file name, underscores become hyphens, folders become "--"
controllers = Dir["app/javascript/controllers/**/*_controller.js"]
report "Stimulus controllers nothing attaches", controllers.reject { |f|
  id = f.delete_prefix("app/javascript/controllers/").delete_suffix("_controller.js").gsub("/", "--").tr("_", "-")
  ruby_id = id.tr("-", "_")
  APP.any? do |file, body|
    next false if file == f

    body.match?(/controller[^\n]*(?<![\w-])#{Regexp.escape(id)}(?![\w-])/) || body.match?(/(?<![\w-])#{Regexp.escape(id)}#\w+/) ||
      body.match?(/data-#{Regexp.escape(id)}-|["']#{Regexp.escape(id)}["']/) || body.match?(/controller: ?[:"']#{ruby_id}/)
  end
}

# 3. Partials: a string "name" or "dir/name" (or a render of that path) somewhere in app/ or lib/; Blacklight overrides listed apart
blacklight_views = begin
  Gem::Specification.find_by_name("blacklight").full_gem_path + "/app/views"
rescue Gem::MissingSpecError
  nil
end
partials = Dir["app/views/**/_*.erb"].reject { |f| f.include?("/kaminari/") }
unrendered = partials.reject do |f|
  rel = f.delete_prefix("app/views/")
  name = File.basename(rel).sub(/\A_/, "").sub(/\..*\z/, "")
  dir = File.dirname(rel)
  # config.show.partials = [ :persistent_link ] renders _persistent_link_default
  default_for = name.delete_suffix("_default") if name.end_with?("_default")
  APP.any? { |file, body| file != f && ((default_for && body.include?(":#{default_for}")) || body.include?("#{dir}/#{name}") || body.match?(/render[ (]+(partial: ?)?["']#{name}["']/) || body.match?(/partial: ?["']#{name}["']/)) }
end
blacklight, ours = unrendered.partition { |f| blacklight_views && File.exist?(File.join(blacklight_views, f.delete_prefix("app/views/"))) }
report "partials nothing renders", ours
report "partials that override a Blacklight view (the gem renders them)", blacklight

# 4. Components: the class name (or the file's constant) is mentioned in a file other than its own
components = Dir["app/components/**/*.rb"]
report "components nothing mentions", components.reject { |f|
  const = File.basename(f, ".rb").split("_").map(&:capitalize).join
  own = [ f, f.sub(/\.rb\z/, ".html.erb") ]
  mentions(const, CODE, except: own)
}

# 5. Models, concerns and helpers: top-level constant, and each public helper method
models = Dir["app/{models,controllers/concerns,services}/**/*.rb"] + Dir["lib/**/*.rb"]
report "models and concerns nothing mentions", models.reject { |f|
  const = File.basename(f, ".rb").split("_").map(&:capitalize).join
  mentions(const, CODE, except: [ f ]) || mentions(File.basename(f, ".rb"), CODE, except: [ f ]) ||
    mentions(const.sub(/\A([A-Z][a-z]+)/) { "#{Regexp.last_match(1)}" }, CODE, except: [ f ])
}
helper_methods = Dir["app/helpers/**/*.rb"].flat_map do |f|
  File.read(f).scan(/^\s*def (\w+[?!]?)/).flatten.map { |m| [ f, m ] }
end
report "helper methods nothing calls", helper_methods.reject { |f, m| mentions(m, CODE.merge(read_all(%w[app/views/**/*.erb])), except: []) && CODE.sum { |file, b| b.scan(/(?<![\w])#{Regexp.escape(m)}(?![\w])/).size } > 1 }.map { |f, m| "#{m}  (#{f})" }

# 6. Images: file name mentioned anywhere in app/ or config/
images = Dir["app/assets/images/**/*"].select { |f| File.file?(f) }
report "images nothing mentions", images.reject { |f| mentions(File.basename(f), APP) || mentions(File.basename(f, ".*"), APP.select { |k, _| k.end_with?(".rb") }) }

# 7. Routes: needs the app, so it is last and skipped with --no-routes
unless ARGV.include?("--no-routes")
  ENV["RAILS_ENV"] ||= "test"
  require_relative "../config/environment"
  named = Rails.application.routes.routes.filter_map { |r| [ r.name, r.defaults[:controller] ] if r.name }.uniq
  routes_file = [ "config/routes.rb" ]
  report "named routes whose helper nothing calls", named.reject { |name, _|
    mentions("#{name}_path", CODE, except: routes_file) || mentions("#{name}_url", CODE, except: routes_file) ||
      mentions(":#{name}", CODE, except: routes_file)
  }.map { |name, controller| "#{name}  (#{controller})" }
end

puts "\nLocale strings: run ruby script/i18n_check.rb"
