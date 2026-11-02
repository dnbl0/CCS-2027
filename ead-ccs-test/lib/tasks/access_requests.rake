require "csv"

namespace :access_requests do
  desc "Print the pending access requests as CSV to stdout, so staff can action them until there is an admin screen"
  task export: :environment do
    puts CSV.generate_line(%w[id requested_at request_type document_id document_title name email organisation purpose])
    AccessRequest.pending.order(:created_at).find_each do |request|
      puts CSV.generate_line([ request.id, request.created_at.iso8601, request.request_type, request.document_id, request.document_title,
                               request.name, request.email, request.organisation, request.purpose ])
    end
  end
end
