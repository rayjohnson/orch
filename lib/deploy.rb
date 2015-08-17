require 'json'
require 'net/http'
require 'uri'

require 'config'

module Orch
  class Deploy
    def initialize(options)
      # TODO: get chronos and marathon urls from diffferent ways: param, env, .config
      @config = Orch::Config.new(options)
    end

    def deploy_chronos(json_payload)
      uri = URI(@config.chronos_url)
      json_headers = {"Content-Type" => "application/json",
                "Accept" => "application/json"}

      # curl -L -H 'Content-Type: application/json' -X POST -d @$schedule_file $CHRONOS_URL/scheduler/iso8601
      puts uri
      http = Net::HTTP.new(uri.host, uri.port)
      puts "1"
      puts "#{uri.path}"
      response = http.post("/scheduler/iso8601", json_payload, json_headers)

      puts "Response #{response.code} #{response.message}: #{response.body}"

      return response
    end
  end
end
