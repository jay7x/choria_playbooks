#!/opt/puppetlabs/puppet/bin/ruby
#
#  "parameters": {
#    "url": {
#      "description": "URL to query",
#      "type": "String[1]"
#    },
#    "method": {
#      "description": "Method to use (GET/POST/...)",
#      "type": "Enum['GET','POST','PUT','DELETE','HEAD','LIST']"
#    },
#    "headers": {
#      "description": "Hash of headers to send",
#      "type": "Hash"
#    },
#    "data": {
#      "description": "Data to send",
#      "type": "String"
#    }

require 'uri'
require 'net/http'
require 'json'

# Query prometheus exporter for metrics requested
class QueryRest
  KIND = 'example/query_rest'.freeze
  USER_AGENT = 'example::query_rest'.freeze

  # QueryRest::Error
  class Error < RuntimeError
    attr_reader :kind, :details, :issue_code

    def initialize(msg, kind, details = nil)
      super(msg)
      @kind = kind
      @issue_code = issue_code
      @details = details || {}
    end

    def to_h
      { 'kind' =>  kind,
        'msg' => message,
        'details' => details }
    end
  end

  def task(url: nil, method: 'GET', headers: {}, data: '')
    valid_methods = ['GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'LIST']
    raise QueryRest::Error.new("'url' parameter is required", "#{KIND}/url_not_defined") unless url
    raise QueryRest::Error.new("'method' must be one of: #{valid_methods.join(',')}", "#{KIND}/method_unknown") unless valid_methods.include?(method)

    res = {}

    begin
      resp = do_request(url, method, headers, data)
      res['code'] = resp.code
      res['message'] = resp.message
      res['body'] = resp.body
      res['headers'] = resp.to_hash
    rescue StandardError => e
      raise QueryRest::Error.new(e.message, "#{KIND}/task", class: e.class.to_s)
    end

    res.to_json
  end

  def do_request(url, method, headers, data)
    uri = URI.parse(url)

    # Stringify headers (do opposite to walk_keys)
    h = headers.transform_keys(&:to_s)
    h['User-Agent'] = USER_AGENT unless headers['User-Agent']

    Net::HTTP.start(uri.host, uri.port) do |http|
      http.send_request(method, uri, data, h)
    end
  end

  # Accepts a Data object and returns a copy with all hash keys
  # symbolized.
  def self.walk_keys(data)
    if data.is_a? Hash
      data.each_with_object({}) do |(k, v), acc|
        v = walk_keys(v)
        acc[k.to_sym] = v
      end
    elsif data.is_a? Array
      data.map { |v| walk_keys(v) }
    else
      data
    end
  end

  def self.run
    input = STDIN.read
    params = walk_keys(JSON.parse(input))

    # This method accepts a hash of parameters to run the task, then executes
    # the task. Unhandled errors are caught and turned into an error result.
    # @param [Hash] params A hash of params for the task
    # @return [Hash] The result of the task
    result = new.task(params)

    if result.class == Hash
      STDOUT.print JSON.generate(result)
    else
      STDOUT.print result.to_s
    end
  rescue QueryRest::Error => e
    STDOUT.print({ _error: e.to_h }.to_json)
    exit 1
  rescue StandardError => e
    error = QueryRest::Error.new(e.message, e.class.to_s, e.backtrace)
    STDOUT.print({ _error: error.to_h }.to_json)
    exit 1
  end
end

if $PROGRAM_NAME == __FILE__
  QueryRest.run
end
