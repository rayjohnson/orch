# Chronos interface object
require 'json'
require 'net/http'
require 'uri'

require 'orch/config'
require "orch/util"

class String
  def numeric?
    Float(self) != nil rescue false
  end
end

module Orch
  class Chronos

    include Orch::Util

    def deploy(url_list, json_payload)
      if url_list.nil?
        exit_with_msg "chronos_url not defined"
      end

      path = nil
      path = "/scheduler/iso8601" unless json_payload["schedule"].nil?
      path = "/scheduler/dependency" unless json_payload["parents"].nil?
      if path.nil?
        exit_with_msg "neither schedule nor parents fields defined for Chronos job"
      end

      response = http_post(url_list, path, json_payload, JSON_HEADERS)

      if response.code != 204.to_s
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

      return response
    end

    def delete(url_list, name)
      if url_list.nil?
        exit_with_msg "chronos_url not defined"
      end

      # curl -L -X DELETE chronos-node:8080/scheduler/job/request_event_counter_hourly
      response = http_delete(url_list, "/scheduler/job/#{name}", JSON_HEADERS)

      if response.code != 204.to_s
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

      return response
    end

    def verify(url_list, json_payload)
      if url_list.nil?
        puts "no chronos_url - can not verify with server"
        return
      end

      spec = Hashie::Mash.new(JSON.parse(json_payload))

      response = http_get(url_list, "/scheduler/jobs/search?name=#{spec.name}", JSON_HEADERS)

      if response.code != 200.to_s
        puts "Response #{response.code} #{response.message}: #{response.body}"
        foundDiffs = true 
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
        foundDiffs = true 
      end

      return foundDiffs
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
            printf("difference for field: %s - length of array is different\n", key)
            printf("    spec:   %s\n", spec[key].to_json)
            printf("    server: %s\n", job[key].to_json)
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
          printf("difference for field: %s\n", key)
          printf("    spec:   %s\n", specVal)
          printf("    server: %s\n", jobVal)
          foundDiff = true
        end
      end

      return foundDiff
    end
  end
end
