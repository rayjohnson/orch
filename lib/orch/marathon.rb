# Marathon interface object

class String
  def numeric?
    Float(self) != nil rescue false
  end
end

class Orch::Marathon

  include Orch::Util

  def deploy(url_list, app_id, json_payload)
    if url_list.nil?
      exit_with_msg "marathon_url not defined"
    end

    response = http_put(url_list, "/v2/apps/#{app_id}", json_payload, JSON_HEADERS)

    # TODO: should we do anyting with version or deploymentId that gets returned?
    if response.code == 201.to_s
      puts "successfully created marathon job: #{app_id}"
    elsif response.code == 200.to_s
      puts "successfully updated marathon job: #{app_id}"
    elsif response.code == 401.to_s
      puts "Authentication required"
      exit 1
    else
      puts "Response #{response.code} #{response.message}: #{response.body}"
    end

    return response
  end

  def delete(url_list, id)
    if url_list.nil?
      exit_with_msg "marathon_url not defined"
    end

    response = http_delete(url_list, "/v2/apps/#{id}", JSON_HEADERS)

    if response.code == 200.to_s
      puts "successfully deleted #{id}"
    elsif response.code == 404.to_s
      puts "job: #{id} - does not exist to delete"
    else
      puts "Response #{response.code} #{response.message}: #{response.body}"
    end

    return response
  end

  def verify(url_list, json_payload)
    if url_list.nil?
      puts "no marathon_url - can not verify with server"
      return
    end

    spec = Hashie::Mash.new(JSON.parse(json_payload))

    response = http_get(url_list, "/v2/apps/#{spec.id}", JSON_HEADERS)

    if response.code == 200.to_s
      job = Hashie::Mash.new(JSON.parse(response.body))
      foundDiffs = find_diffs(spec, job.app)
    elsif response.code == 401.to_s
      puts "Authentication required"
      exit 1
    elsif response.code == 404.to_s
      puts "job: #{spec.id} - not defined in Marathon"
      foundDiffs = true 
    else
      puts "Response #{response.code} #{response.message}: #{response.body}"
      foundDiffs = true 
    end

    return foundDiffs
  end

  def restart(url_list, app_id)
    if url_list.nil?
      exit_with_msg "marathon_url not defined"
    end

    # POST /v2/apps/{appId}/restart: Rolling restart of all tasks of the given app
    response = http_post(url_list, "/v2/apps/#{app_id}/restart", {}.to_json, JSON_HEADERS)

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
