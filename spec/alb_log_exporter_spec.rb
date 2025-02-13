# frozen_string_literal: true

require_relative "../lib/alb_log_exporter"

RSpec.describe AlbLogExporter do
  subject(:exporter) { described_class.new(loggly_token: "faketoken") }

  let(:logger_class) { class_double(Logger) }
  let(:logger) { instance_double(Logger, debug: nil, info: nil, error: nil) }
  let(:s3_client_class) { class_double(Aws::S3::Client) }
  let(:s3_client) { instance_double(Aws::S3::Client) }

  before do
    s3_client_class.as_stubbed_const
    allow(s3_client_class).to receive(:new).and_return(s3_client)
  end

  def stub_logger
    logger_class.as_stubbed_const
    allow(logger_class).to receive(:new).and_return(logger)
  end

  def stub_s3_get_object(bucket:, key:, io:)
    allow(s3_client).to receive(:get_object)
      .with(bucket:, key:)
      .and_return(
        instance_double(
          Aws::S3::Types::GetObjectOutput,
          body: io
        )
      )
  end

  describe "#process_event" do
    it "fails if the event has no records" do
      stub_logger
      event = {}

      expect { exporter.process_event(event:) }.to raise_error(/No records/)
    end

    it "processes an uncompressed log file" do
      stub_logger
      event = {
        "Records" => [
          {
            "s3" => {
              "bucket" => { "name" => "dummybucket" },
              "object" => { "key" => "filekey.log" }
            }
          }
        ]
      }
      stub_s3_get_object(
        bucket: "dummybucket",
        key: "filekey.log",
        io: File.open("#{__dir__}/support/example.log")
      )
      stub_request(:post, /logs-01\.loggly\.com/)

      exporter.process_event(event: event)

      expect(logger).not_to have_received(:error)
      example_output = File.read("#{__dir__}/support/example.ndjson")
      expect(WebMock)
        .to have_requested(
          :post,
          "https://logs-01.loggly.com/bulk/faketoken/tag/access_logs/"
        )
        .once
        .with(body: example_output)
    end

    it "processes a single compressed log file" do
      stub_logger
      event = {
        "Records" => [
          {
            "s3" => {
              "bucket" => { "name" => "dummybucket" },
              "object" => { "key" => "filekey.log.gz" }
            }
          }
        ]
      }
      stub_s3_get_object(
        bucket: "dummybucket",
        key: "filekey.log.gz",
        io: File.open("#{__dir__}/support/example.log.gz")
      )
      stub_request(:post, /logs-01\.loggly\.com/)
      exporter.process_event(event: event)
      expect(logger).not_to have_received(:error)
      example_output = File.read("#{__dir__}/support/example.ndjson")
      expect(WebMock)
        .to have_requested(
          :post,
          "https://logs-01.loggly.com/bulk/faketoken/tag/access_logs/"
        )
        .once
        .with(body: example_output)
    end

    it "extracts multiple log files from the event"
    it "handles errors"
  end
end
