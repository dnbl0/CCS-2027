namespace :record_views do
  desc "Remove the daily view counts older than TRENDING_KEEP_DAYS (default 35). Schedule it daily (docs/similar-and-trending.md)"
  task prune: :environment do
    removed = RecordView.prune
    puts "Removed #{removed} rows of view counts older than #{RecordView.keep_days} days"
  end
end
