# frozen_string_literal: true

require_relative "lib/alb_log_exporter"

# LambdaHandler passes data from the S3 Event to the log exporter
class LambdaHandler
  @exporter = AlbLogExporter.new(loggly_token: ENV.fetch("LOGGLY_TOKEN"))

  def self.call(event:, **_options)
    @exporter.process_event(event:)
  end
end
