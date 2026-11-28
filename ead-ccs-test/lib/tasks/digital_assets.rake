namespace :digital_assets do
  desc "Make the thumbnails (800 px) and large images (1600 px) listed in config/digital_assets.yml (SOURCE_DIR holds the originals; needs vipsthumbnail)"
  task thumbnails: :environment do
    # The originals were in the 2026 prototype (public/assets/images/collections, removed 27 Nov 2026; still in the git history)
    source_dir = Pathname(ENV.fetch("SOURCE_DIR") { abort "Set SOURCE_DIR to the folder of original images (docs/blacklight-features.md)" })
    sizes = { "thumbs" => 800, "large" => 1600 }
    sizes.each_key { |dir| FileUtils.mkdir_p(Rails.root.join("public/digital-assets", dir)) }

    made = 0
    YAML.safe_load_file(Rails.root.join(Collections::DigitalAssets::CONFIG)).each_value do |files|
      files.each do |file|
        source = source_dir.join(file)
        abort "missing original: #{source}" unless source.exist?

        sizes.each do |dir, pixels|
          target = Rails.root.join("public/digital-assets", dir, Collections::DigitalAssets.thumbnail_name(file))
          system("vipsthumbnail", source.to_s, "--size", "#{pixels}x#{pixels}", "-o", "#{target}[Q=85,strip]", exception: true)
          made += 1
        end
      end
    end
    puts "Made #{made} images in public/digital-assets"
  end
end
