# frozen_string_literal: true

module Dam
  # A DAM sync that cannot go on: the DAM refused or kept failing, a search came back short, or the index is not configured
  class Error < StandardError; end
end
