# frozen_string_literal: true

# This should translate the space-separated alb log lines to a more
# comprehensible json format
class AlbLogParser
  IP_ADDR = /
    (?:\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})
    |
    (?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}
  /x
  LOG_ENTRY_REGEX = %r{
    \A (?<request_type> \S+ )
    \s (?<timestamp> \S+ )
    \s (?<elb> \S+ )
    \s (?<client_ip> #{IP_ADDR} )
       :
       (?<client_port> \d{0,6} )
    \s (?:
         (?:
           (?<target_ip> #{IP_ADDR} )
           :
           (?<target_port> \d{0,6} )
         )
         |
         (?<target> \S+ )
       )
    \s (?<request_processing_time> [\d.]+ )
    \s (?<target_processing_time> [\d.]+ )
    \s (?<response_processing_time> [\d.]+ )
    \s (?<elb_status_code> \S+ )
    \s (?<target_status_code> \S+ )
    \s (?<received_bytes> \S+ )
    \s (?<sent_bytes> \S+ )
    \s "
         (?:
           (?:
             (?<request_method> [A-Z]+ )
             \s
             (?<request_url> [^"]* )
             \s
             (?<request_http_ver>HTTP/[\d.]+)
           )
           |
           (?<request>[^"]*)
         )
       "
    \s "(?<user_agent> [^"]* )"
    \s (?<ssl_cipher> \S+ )
    \s (?<ssl_protocol> \S+ )
    \s (?<target_group_arn> \S+ )
    \s "(?<trace_id> [^"]* )"
    \s "(?<domain_name> [^"]* )"
    \s "(?<chosen_cert_arn> [^"]* )"
    \s (?<matched_rule_priority> \S+ )
    \s (?<request_creation_time> \S+ )
    \s "(?<actions_executed> [^"]* )"
    \s "(?: - | (?<redirect_url> [^"]* ))"
    \s "(?<error_reason> [^"]* )"
    \s "(?:[^"]* )"                          # "target:port_list" is duplicative
                                             # of target_ip/target_port
    \s "(?:[^"]* )"                          # "target_status_code_list" is a
                                             # duplicate of target_status_code
    \s "(?<classification> [^"]* )"
    \s "(?<classification_reason> [^"]* )"
    \s (?<conn_trace_id> \S+ )
  }x
  FIELD_REGEX = /(?:(?:"[^"]+")|(?:[^ "]+))/
  DESIRED_FIELDS = %w[
    request_type
    timestamp
    client_ip
    target_ip
    target
    request_processing_time
    target_processing_time
    response_processing_time
    elb_status_code
    target_status_code
    received_bytes
    sent_bytes
    request_method
    request_url
    request
    user_agent
    target_group_arn
    request_creation_time
    redirect_url
  ].freeze

  def parse_line(input)
    match_data = LOG_ENTRY_REGEX.match(input)
    raise ArgumentError, "couldn't parse #{input.inspect}" if match_data.nil?

    match_data.named_captures.compact.slice(*DESIRED_FIELDS)
              .then { process_number_fields(_1) }
  end

  private

  def process_number_fields(hash)
    hash.transform_values do |value|
      case value
      when /^\d+\.\d+$/
        value.to_f
      when /^[1-9]\d*$/
        value.to_i
      else
        value
      end
    end
  end
end
