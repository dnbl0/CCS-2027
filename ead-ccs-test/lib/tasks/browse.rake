# frozen_string_literal: true

namespace :browse do
  desc "Build the Browse page's cards now (they are otherwise built by the first visit after a day), e.g. after a deploy or a reindex"
  task warm_cards: :environment do
    Browse::Cards.warm
    puts "Browse cards built for #{BrowseHubs.all.size} ways in."
  end
end
