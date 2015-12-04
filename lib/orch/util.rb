module Orch::Util
  HTTP_ERRORS = [
    EOFError,
    Errno::ECONNRESET,
    Errno::EINVAL,
    Net::HTTPBadResponse,
    Net::HTTPHeaderSyntaxError,
    Net::ProtocolError,
    Timeout::Error,
    Errno::ECONNREFUSED,
    Errno::ETIMEDOUT
  ]

  JSON_HEADERS = {"Content-Type" => "application/json",
                  "Accept" => "application/json"}

  def http_post(url_list, path, body, headers)
    lastErr = nil

    url_list.split(';').each do |url|
      uri = URI(url)

      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(path, headers)
      request.body = body
      if uri.user
        request.basic_auth URI.unescape(uri.user), URI.unescape(uri.password)
      end
      begin
        #response = http.post(path, body, headers)
        response = http.start {|http| http.request(request) }
      rescue *HTTP_ERRORS => error
        STDERR.puts "Failed http_post to #{url}: #{error} (#{error.class})"
        lastErr = error
        next
      end

      return response
    end

    http_fault(lastErr)
  end

  def http_put(url_list, path, body, headers)
    lastErr = nil

    url_list.split(';').each do |url|
      uri = URI(url)

      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Put.new(path, headers)
      request.body = body
      if uri.user
        request.basic_auth URI.unescape(uri.user), URI.unescape(uri.password)
      end
      begin
        #response = http.put(path, body, headers)
        response = http.start {|http| http.request(request) }
      rescue *HTTP_ERRORS => error
        STDERR.puts "Failed http_put to #{url}: #{error} (#{error.class})"
        lastErr = error
        next
      end

      return response
    end

    http_fault(lastErr)
  end

  def http_get(url_list, path, headers)
    lastErr = nil

    url_list.split(';').each do |url|
      uri = URI(url)

      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(path, headers)
      if uri.user
        request.basic_auth URI.unescape(uri.user), URI.unescape(uri.password)
      end
      begin
        #response = http.get(path, headers)
        response = http.start {|http| http.request(request) }
      rescue *HTTP_ERRORS => error
        STDERR.puts "Failed http_get to #{url}: #{error} (#{error.class})"
        lastErr = error
        next
      end

      return response
    end

    http_fault(lastErr)
  end

  def http_delete(url_list, path, headers)
    lastErr = nil

    url_list.split(';').each do |url|
      uri = URI(url)

      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Delete.new(path, headers)
      if uri.user
        request.basic_auth URI.unescape(uri.user), URI.unescape(uri.password)
      end
      begin
        # response = http.delete(path, headers)
        response = http.start {|http| http.request(request) }
      rescue *HTTP_ERRORS => error
        STDERR.puts "Failed http_delete to #{url}: #{error} (#{error.class})"
        lastErr = error
        next
      end

      return response
    end

    http_fault(lastErr)
  end

  def http_fault(error)
    raise "Fatal networking error talking to framework: #{error.to_s}"
  end

  def exit_with_msg(err_msg)
    raise err_msg
  end

  def to_float str
    Float(str) rescue ArgumentError
  end
end
