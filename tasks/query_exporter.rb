#!/opt/puppetlabs/puppet/bin/ruby
#
#  "parameters": {
#    "url": {
#      "description": "Exporter URL to query",
#      "type": "String[1]"
#    },
#    "metrics": {
#      "description": "Metrics to fetch",
#      "type": "Optional[Array[String]]"
#    }
#  }

require 'json'
require 'open-uri'

# Query prometheus exporter for metrics requested
class QueryExporter
  def kind
    'example/query_exporter'
  end

  # QueryExporter::Error
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

  def task(url: nil, metrics: [])
    raise QueryExporter::Error.new("'url' parameter is required", "#{kind}/url_not_defined") unless url
    res = {}

    begin
      content = fetch_metrics(url)
      res['metrics'] = grep_metrics(content, metrics)
    rescue StandardError => e
      raise QueryExporter::Error.new(e.message, "#{kind}/task", class: e.class.to_s)
    end
    res.to_json
  end

  def fetch_metrics(uri)
    username = ''
    password = ''
    if (match = uri.match(%r{(http\://|https\://)(.*):(.*)@(.*)}))
      # If URL is in the format of https://username:password@example.local:9100/metrics
      protocol, username, password, path = match.captures
      url = "#{protocol}#{path}"
    elsif (match = uri.match(%r{(http\:\/\/|https\:\/\/)(.*)@(.*)}))
      # If URL is in the format of https://username@example.local:9200/metrics
      protocol, username, path = match.captures
      url = "#{protocol}#{path}"
    else
      url = uri
    end
    begin
      content = OpenURI.open_uri(url, http_basic_authentication: [username, password])
    rescue OpenURI::HTTPError => err
      r = err.io
      warning("Can't load '#{url}' (#{r.status[0]})")
      []
    end
    content.readlines
  end

  def grep_metrics(content, metrics)
    found = {}
    content.each do |line|
      next if line.start_with?('#') || line.chomp.strip.empty?

      nl, value = line.split(' ')
      name, = nl.split('{')
      unless metrics.empty?
        next unless metrics.include?(name) || metrics.include?(nl)
      end
      found[nl.to_sym] = value
    end
    found
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
  rescue QueryExporter::Error => e
    STDOUT.print({ _error: e.to_h }.to_json)
    exit 1
  rescue StandardError => e
    error = QueryExporter::Error.new(e.message, e.class.to_s, e.backtrace)
    STDOUT.print({ _error: error.to_h }.to_json)
    exit 1
  end
end

if $PROGRAM_NAME == __FILE__
  QueryExporter.run
end
