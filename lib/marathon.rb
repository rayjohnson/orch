# Marathon interface object
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
  class Marathon
    def initialize(options)
      # TODO: get chronos and marathon urls from diffferent ways: param, env, .config
      @config = Orch::Config.new(options)
    end

    def deploy(app_id, json_payload)
      uri = URI(@config.marathon_url)
      json_headers = {"Content-Type" => "application/json",
                "Accept" => "application/json"}

      http = Net::HTTP.new(uri.host, uri.port)
      response = http.put("/v2/apps/#{app_id}", json_payload, json_headers)

      # TODO: should we do anyting with version or deploymentId that gets returned?
      if response.code == 201.to_s
        puts "successfully created marathon job: #{app_id}"
      elsif response.code == 200.to_s
        puts "successfully updated marathon job: #{app_id}"
      else
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

      return response
    end

    def delete(id)
      uri = URI(@config.marathon_url)
      json_headers = {"Content-Type" => "application/json",
                "Accept" => "application/json"}
      puts uri

      http = Net::HTTP.new(uri.host, uri.port)
      response = http.delete("/v2/apps/#{id}", json_headers)

      puts "Response #{response.code} #{response.message}: #{response.body}"

      if response.code == 200.to_s
        puts "success"
      end

      # TODO: handle error codes

      return response
    end

    def verify(json_payload)
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

    def restart(app_id)
      # POST /v2/apps/{appId}/restart: Rolling restart of all tasks of the given app
      uri = URI(@config.marathon_url)
      json_headers = {"Content-Type" => "application/json",
                "Accept" => "application/json"}

      http = Net::HTTP.new(uri.host, uri.port)
      response = http.post("/v2/apps/#{app_id}/restart", {}.to_json, json_headers)

      if response.code == 200.to_s
        puts "success"
      else
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

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
          end
          # TODO: this will not work if arrays are not in same order
          spec[key].zip(job[key]).each do |subSpec, subJob|
            if find_diffs(subSpec, subJob) == true
              foundDiff = true
            end
            next
          end
          next
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
        # Marathon changes the spec in some cases - handle them specially
        if key == "id"
          # At a basic level marathon adds a / to the front of the id we pass in...
          jobVal.sub!("/", "")
        end
        if specVal != jobVal
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