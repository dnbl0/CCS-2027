# Sass entry points compiled to app/assets/builds (git-ignored; built by `rails dartsass:build`,
# which assets:precompile runs automatically, and watched by `bin/dev`).
# Bootstrap's own Sass comes from the bootstrap gem, whose asset path dartsass uses as a load path.
Rails.application.config.dartsass.builds = {
  "bootstrap-uom.scss" => "bootstrap-uom.css"
}

# Bootstrap 5.3 still uses @import and the global-builtin functions internally.
Rails.application.config.dartsass.build_options = [
  "--style=compressed",
  "--no-source-map",
  "--quiet-deps",
  "--silence-deprecation=import",
  "--silence-deprecation=global-builtin",
  "--silence-deprecation=color-functions"
]
