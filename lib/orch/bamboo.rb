# Chronos interface object
require 'json'

require 'orch/config'
require 'orch/util'

class String
  def numeric?
    Float(self) != nil rescue false
  end
end

module Orch
  class Bamboo

    include Orch::Util

    def deploy(url_list, app_id, bamboo_spec)
      if url_list.nil?
        exit_with_msg "bamboo_url not defined"
      end

      # Create the real json 
      bamboo_json = {}
      bamboo_json["id"] = (app_id[0] == '/') ? app_id : ("/" + app_id)
      bamboo_json["acl"] = bamboo_spec["acl"]

  # curl -i -X PUT -d '{"id":"/ExampleAppGroup/app1", "acl":"path_beg -i /group/app-1"}' http://localhost:8000/api/services//ExampleAppGroup/app1
# {"/adam-web-dev":{"Id":"/adam-web-dev","Acl":"hdr(host) -i adam-web-dev.ypec.int.yp.com"
      response = http_put(url_list, "/api/services/#{app_id}", bamboo_json.to_json, JSON_HEADERS)

      if response.code == 200.to_s
        puts "successfully created bamboo spec for marathon job: #{app_id}"
      else
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

      return response
    end

    def delete(url_list, app_id)
      if url_list.nil?
        exit_with_msg "bamboo_url not defined"
      end

      response = http_delete(url_list, "/api/services/#{app_id}", JSON_HEADERS)

      if response.code != 200.to_s
        puts "Response #{response.code} #{response.message}: #{response.body}"
      end

      return response
    end

    def verify(url_list, app_id, spec)
      if url_list.nil?
        puts "no bamboo_url - can not verify with server"
        return
      end

      # TODO: will this work or do I need to parse through all services like chronos
      response = http_get(url_list, "/api/services", JSON_HEADERS)

      if response.code != 200.to_s
        puts "Response #{response.code} #{response.message}: #{response.body}"
        foundDiffs = true 
      end

      allJobs = Hashie::Mash.new(JSON.parse(response.body))

      # Bamboo api only returns all items
      jobFound = false
      allJobs.each do |key, job|
        if key == app_id
          jobFound = true
          # Bamboo returns keys with different case then you send them!
          # Right now the only field to compar is Acl so we only check it by hand
          if spec["acl"] != job["Acl"]
            printf "difference for field: acl\n"
            printf "    spec:   #{spec["acl"]}\n"
            printf "    server: #{job["Acl"]}\n"
            foundDiffs = true 
          end
    

        end
      end
      
      if !jobFound
        puts "bamboo spec for marathon job \"#{app_id}\" not currently deployed"
        foundDiffs = true 
      end

      # TODO: handle error codes better?

      return foundDiffs
    end

  end
end
