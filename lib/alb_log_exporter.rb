# frozen_string_literal: true

require "logger"
require "json"
require "zlib"
require "net/http"
require "aws-sdk-s3"
require_relative "alb_log_parser"

# Downloads log files from S3, parses them to JSON and sends them to Loggly
class AlbLogExporter
  LOGGLY_HOST = "logs-01.loggly.com"

  def initialize(loggly_token:)
    @logger = Logger.new($stdout)
    @loggly_token = loggly_token
    @s3 = Aws::S3::Client.new
    @parser = AlbLogParser.new
  end

  def process_event(event:)
    @logger.info("event = #{JSON.dump(event)}")
    raise ArgumentError, "No records!" unless event.key?("Records")

    log_files = s3_objects(event["Records"])
    @logger.info("got #{log_files.length} files: #{log_files.inspect}")

    log_files.each do |bucket, key|
      file = fetch_log_file(bucket:, key:)
      send_logs_to_loggly(file:)
    rescue StandardError => e
      @logger.error(e.full_message)
    end
  end

  def s3_objects(records)
    records.map do |record|
      bucket = record.dig("s3", "bucket", "name")
      if bucket.nil? || bucket.empty?
        @logger.error("bad bucket (#{bucket.inspect})")
        next
      end

      key = record.dig("s3", "object", "key")
      @logger.error("bad key") and next if key.nil? || key.empty?

      [bucket, key]
    end
  end

  def fetch_log_file(bucket:, key:)
    @logger.info("fetching file (#{bucket}, #{key})")
    s3_resp = @s3.get_object(bucket: bucket, key: key)
    io = s3_resp.body
    io = Zlib::GzipReader.new(io) if key.end_with?(".gz")
    io
  end

  def send_logs_to_loggly(file:)
    with_loggly_connection do |conn|
      file.each_line.each_slice(1000) do |slice|
        payload = +""
        slice.each do |line|
          payload << @parser.parse_line(line).to_json
          payload << "\n"
        end

        send_to_loggly(conn:, payload:)
      end
    end
  end

  def with_loggly_connection
    Net::HTTP.start(LOGGLY_HOST, 443, use_ssl: true) do |http|
      @logger.debug("opening connection to loggly")
      yield http
      @logger.debug("done with connection to loggly")
    end
  end

  def send_to_loggly(conn:, payload:)
    resp = conn.post("/bulk/#{@loggly_token}/tag/access_logs/", payload)

    @logger.error(resp.inspect) unless resp.is_a?(Net::HTTPSuccess)
    @logger.info("sent #{payload.length} chars to loggly")
    @logger.info("loggly response: #{resp.body}")
  end
end
