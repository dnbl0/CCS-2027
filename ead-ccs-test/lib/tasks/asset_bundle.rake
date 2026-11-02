# Runs after Propshaft's own precompile (the Dockerfile runs assets:precompile): one stylesheet request, and .gz files to serve.
# See lib/asset_bundle.rb. Development and test serve the source files and are not affected.
task "assets:precompile" do
  AssetBundle.run(Rails.root.join("public/assets").to_s)
end
