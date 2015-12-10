module Orch
  # Used to rescue errors we know about. See bin/orch.
  class UserError < StandardError; end

  class AuthenticationError < UserError
    def initialize status, body, urls
      @status = status
      @body = body
      @urls = urls
    end

    def message
      "Unauthorized. status: #{@status}. body: #{@body.chomp}. urls: #{@urls}"
    end
  end
  class MarathonError < UserError; end
end
