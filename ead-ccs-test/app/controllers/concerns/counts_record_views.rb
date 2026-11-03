# frozen_string_literal: true

# Adds one to the record's daily view count (RecordView) after a record page is sent. It counts only what a person looking at a page
# would do: a successful HTML GET, with a browser-like user agent, that is not a prefetch and that the bot controls would not turn
# away, for a record the discovery sections may list (open or view-only, not sensitive; Discovery.listable?). Nothing about the
# visitor is read beyond that test, and nothing of it is kept. A request BotGuard refuses (a blocked crawler, a rate limit) never
# reaches the controller, so it is not counted either.
module CountsRecordViews
  extend ActiveSupport::Concern

  # Generic signs of a program, not a browser: names a crawler, monitor, link preview or HTTP library gives itself
  AUTOMATED_AGENT = /bot\b|bot[\/;)\s]|crawl|spider|slurp|scrap|fetch|headless|lighthouse|phantom|monitor|uptime|preview|archiver|
                     curl|wget|httpie|python|ruby|java\/|go-http|okhttp|libwww|axios|node-fetch|postman|facebookexternalhit|embedly|
                     validator|checker|scan/ix

  included do
    after_action :count_record_view, only: :show
  end

  # Is this request one a person made with a browser? (public so the rule is testable on its own)
  def self.human_looking?(request)
    agent = request.user_agent.to_s
    request.get? && request.format.html? && agent.present? && !agent.match?(AUTOMATED_AGENT) && !BotControls.blocked_user_agent?(agent) &&
      %w[Purpose Sec-Purpose X-Moz].none? { |name| request.headers[name].to_s.match?(/prefetch|prerender/i) }
  end

  private

  def count_record_view
    return unless response.successful? && @document && CountsRecordViews.human_looking?(request) && Discovery.listable?(@document)

    RecordView.record(@document.id)
  rescue StandardError => error
    Rails.logger.warn("Record view not counted: #{error.class}: #{error.message}")
  end
end
