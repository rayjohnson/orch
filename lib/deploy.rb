require 'json'
require 'net/http'
require 'uri'

require 'config'

class String
  def numeric?
    Float(self) != nil rescue false
  end
end

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
      http = Net::HTTP.new(uri.host, uri.port)
      response = http.post("/scheduler/iso8601", json_payload, json_headers)

      if response.code != 204.to_s
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

      # TODO: handle error codes better?

      return response
    end

    def verify_chronos(json_payload)
      if @config.check_for_chronos_url == false
        puts "no chronos_url - can not verify with server"
        return
      end

      spec = Hashie::Mash.new(JSON.parse(json_payload))

      uri = URI(@config.chronos_url)
      json_headers = {"Content-Type" => "application/json",
                "Accept" => "application/json"}

      # curl -L -H 'Content-Type: application/json' -X POST -d @$schedule_file $CHRONOS_URL/scheduler/iso8601
      http = Net::HTTP.new(uri.host, uri.port)
      response = http.get("/scheduler/jobs", json_headers)

      if response.code != 200.to_s
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

      array = JSON.parse(response.body).map { |hash| Hashie::Mash.new(hash) }

      jobFound = false
      array.each do |job|
        if job.name == spec.name
          jobFound = true
          foundDiffs = find_diffs(spec, job)
        end
      end
      
      if !jobFound
        puts "job \"#{spec.name}\" not currently deployed"
      end

      # TODO: handle error codes better?

      return response
    end

    def find_diffs(spec, job)
      foundDiff = false

      spec.each_key do |key|
        if spec[key].is_a?(Hash)
          if find_diffs(spec[key], job[key]) == true
            foundDiff = true
          end
          next
        end
        # TODO: not sure how to compare arrays
        specVal = spec[key]
        jobVal = job[key]
        if spec[key].to_s.numeric?
          specVal = Float(spec[key])
          jobVal = Float(job[key])
        else
          specVal = spec[key]
          jobVal = job[key]
        end
        if specVal != jobVal
          puts "#{key}= spec:#{specVal}, server:#{jobVal}"
          foundDiff = true
        end
      end

      return foundDiff
    end

    def deploy_marathon(json_payload)
      uri = URI(@config.marathon_url)
      json_headers = {"Content-Type" => "application/json",
                "Accept" => "application/json"}
      puts uri

      http = Net::HTTP.new(uri.host, uri.port)
      response = http.put("/v2/apps/#{json_payload["id"]}", json_payload, json_headers)

      puts "Response #{response.code} #{response.message}: #{response.body}"

      if response.code == 204.to_s
        puts "success"
      end

      # TODO: handle error codes

      return response
    end

    def verify_marathon(json_payload)
      if @config.check_for_marathon_url == false
        puts "no marathon_url - can not verify with server"
        return
      end

      spec = Hashie::Mash.new(JSON.parse(json_payload))

      uri = URI(@config.marathon_url)
      json_headers = {"Content-Type" => "application/json",
                "Accept" => "application/json"}

      http = Net::HTTP.new(uri.host, uri.port)
      response = http.get("/v2/apps/#{spec.id}", json_headers)

      # puts "Response #{response.code} #{response.message}: #{response.body}"

      if response.code == 404.to_s
        puts "job: #{spec.id} - is not deployed"
        return
      end

      if response.code == 200.to_s
        job = Hashie::Mash.new(JSON.parse(response.body))
        foundDiffs = find_diffs(spec, job.app)
      end

      # TODO: handle error codes

      return response
    end

  end
end
