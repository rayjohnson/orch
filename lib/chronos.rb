# Chronos interface object
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
  class Chronos
    def initialize(options)
      # TODO: get chronos and marathon urls from diffferent ways: param, env, .config
      @config = Orch::Config.new(options)
    end

    def deploy(json_payload)
      uri = URI(@config.chronos_url)
      json_headers = {"Content-Type" => "application/json",
                "Accept" => "application/json"}

      path = nil
      path = "/scheduler/iso8601" unless json_payload["schedule"].nil?
      path = "/scheduler/dependency" unless json_payload["parents"].nil?
      if path.nil?
        puts "neither schedule nor parents fields defined for Chronos job"
        exit 1
      end

      http = Net::HTTP.new(uri.host, uri.port)
      response = http.post(path, json_payload, json_headers)

      if response.code != 204.to_s
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

      # TODO: handle error codes better?

      return response
    end

    def delete(name)
      uri = URI(@config.chronos_url)
      json_headers = {"Content-Type" => "application/json",
                "Accept" => "application/json"}

      # curl -L -X DELETE chronos-node:8080/scheduler/job/request_event_counter_hourly
      http = Net::HTTP.new(uri.host, uri.port)
      response = http.delete("/scheduler/job/#{name}", json_headers)

      if response.code != 204.to_s
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

      # TODO: handle error codes better?

      return response
    end

    def verify(json_payload)
      if @config.check_for_chronos_url == false
        puts "no chronos_url - can not verify with server"
        return
      end

      spec = Hashie::Mash.new(JSON.parse(json_payload))

      uri = URI(@config.chronos_url)
      json_headers = {"Content-Type" => "application/json",
                "Accept" => "application/json"}

      http = Net::HTTP.new(uri.host, uri.port)
      response = http.get("/scheduler/jobs/search?name=#{spec.name}", json_headers)

      if response.code != 200.to_s
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

      array = JSON.parse(response.body).map { |hash| Hashie::Mash.new(hash) }

      # Chronos search API could return more than one item - make sure we find the exact match
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
        if spec[key].is_a?(Array)
          if spec[key].length != job[key].length
            printf "difference for field: #{key} - length of array is different\n"
            printf "    spec:   #{spec[key].to_json}\n"
            printf "    server: #{job[key].to_json}\n"
            foundDiff = true
            next
          end
          # TODO: not sure how to compare arrays
        end
        specVal = spec[key]
        jobVal = job[key]
        if spec[key].to_s.numeric?
          specVal = Float(spec[key])
          jobVal = Float(job[key])
        else
          specVal = spec[key]
          jobVal = job[key]
        end
        # Chronos changes the case of the Docker argument for some reason
        if key == "type"
          specVal = specVal.upcase
          jobVal = jobVal.upcase
        end
        if specVal != jobVal
          if foundDiff == false
            puts "Differences found in job"
          end
          printf "difference for field: #{key}\n"
          printf "    spec:   #{specVal}\n"
          printf "    server: #{jobVal}\n"
          foundDiff = true
        end
      end

      return foundDiff
    end
  end
end