# frozen_string_literal: true

require_relative "../lib/alb_log_parser"

RSpec.describe AlbLogParser do
  subject(:parser) { described_class.new }

  describe "#parse_line" do
    it "parses a normal https request" do
      input = <<~LOG_LINE.gsub(/\s+/, " ")
        h2 2025-01-06T23:57:22.969776Z app/fakelb/85e233c1f9f64494
        255.145.249.250:57955 10.91.43.28:80
        0.000 0.681 0.000
        200 200
        1121 11971
        "GET https://example.com:443/fakepath/sub HTTP/2.0"
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
        ECDHE-RSA-AES128-GCM-SHA256 TLSv1.2
        arn:aws:elasticloadbalancing:fake-region-3:123456789000:targetgroup/AtlantisWeb
        "Root=1-677c6de2-5d86e20c7d1a0967117a9bfb"
        "example.com" "session-reused" 30
        2025-01-06T23:57:22.288000Z
        "forward" "-" "-" "10.91.43.28:80" "200" "-" "-"
        TID_0369e582b0ffec4da94cba734b7db207
      LOG_LINE
      expected_output = {
        "request_type" => "h2",
        "timestamp" => "2025-01-06T23:57:22.969776Z",
        "client_ip" => "255.145.249.250",
        "target_ip" => "10.91.43.28",
        "request_processing_time" => 0.0,
        "target_processing_time" => 0.681,
        "response_processing_time" => 0.0,
        "elb_status_code" => 200,
        "target_status_code" => 200,
        "received_bytes" => 1121,
        "sent_bytes" => 11_971,
        "request_method" => "GET",
        "request_url" => "https://example.com:443/fakepath/sub",
        "user_agent" =>
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML" \
        ", like Gecko) Chrome/130.0.0.0 Safari/537.36",
        "target_group_arn" =>
        "arn:aws:elasticloadbalancing:fake-region-3:123456789000:targetgroup/" \
        "AtlantisWeb",
        "request_creation_time" => "2025-01-06T23:57:22.288000Z"
      }

      expect(parser.parse_line(input)).to eq(expected_output)
    end

    it "parses a bad line" do
      input = <<~LOG_LINE.gsub(/\s+/, " ")
        https 2025-02-18T19:47:39.417332Z app/fakelb/85e233c1f9f64494
        255.203.249.63:57786
        - -1 -1 -1 500 - 199 227
        "GET https://29.29.29.29:443/ HTTP/1.1"
        "Evilbot"
        ECDHE-RSA-AES128-GCM-SHA256
        TLSv1.2 -
        "Root=1-67b4e3db-1aa06a2f2ea8466d492f3e53"
        "-"
        "fakecert"
        0
        2025-02-18T19:47:39.417000Z
        "fixed-response" "-" "-" "-" "-" "-" "-"
        TID_4420b83d6a496c46bcc6be6a6e5e6873
      LOG_LINE
      expected_output = {
        "request_type" => "https",
        "timestamp" => "2025-02-18T19:47:39.417332Z",
        "client_ip" => "255.203.249.63",
        "target" => "-",
        "request_processing_time" => -1,
        "target_processing_time" => -1,
        "response_processing_time" => -1,
        "elb_status_code" => 500,
        "target_status_code" => "-",
        "received_bytes" => 199,
        "sent_bytes" => 227,
        "request_method" => "GET",
        "request_url" => "https://29.29.29.29:443/",
        "user_agent" => "Evilbot",
        "target_group_arn" => "-",
        "request_creation_time" => "2025-02-18T19:47:39.417000Z"
      }

      expect(parser.parse_line(input)).to eq(expected_output)
    end
  end
end
