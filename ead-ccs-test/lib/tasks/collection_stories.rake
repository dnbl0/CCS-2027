namespace :stories do
  desc "Harvest the collection websites' stories (config/collection_story_sources.yml) into config/collection_stories.yml " \
       "(OUT=path to write elsewhere). Reads the sites and Solr; review the diff before committing"
  task harvest: :environment do
    result = CollectionStories::Harvester.new(sources: CollectionStories::Source.load, fetch: CollectionStories::Fetcher,
                                              matcher: CollectionStories::SolrMatcher).call
    result.errors.each { |error| warn "could not read: #{error}" }
    out = ENV["OUT"].presence || CollectionStories::PATH.to_s
    File.write(out, CollectionStories::Harvester.yaml(result))
    result.stories.each { |story| puts "matched    #{story.title} -> #{story.record_ids.join(', ')}" }
    result.unmatched.each { |story| puts "curator    #{story.title} (#{story.reason})" }
    puts "Wrote #{out}."
  end
end
