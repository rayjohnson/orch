require 'net/http'

HTTP_ERRORS = [
  EOFError,
  Errno::ECONNRESET,
  Errno::EINVAL,
  Net::HTTPBadResponse,
  Net::HTTPHeaderSyntaxError,
  Net::ProtocolError,
  Timeout::Error,
  Errno::ECONNREFUSED
]

def http_fault(error)
  puts "Networking error talking to framework: #{error.to_s}"
  exit 1
end

def exit_with_msg(err_msg)
  puts err_msg
  exit 1
end