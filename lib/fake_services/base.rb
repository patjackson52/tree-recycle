# Base class for all fake service implementations
#
# This provides common functionality for fake services:
# - Logging
# - Warning messages
# - Base initialization
#
# Usage:
#   class FakeSmsClient < FakeServices::Base
#     def initialize
#       super('SMS')
#     end
#
#     def send_message(to, body)
#       log("Sending SMS to #{to}: #{body}")
#       # ... fake implementation
#     end
#   end

module FakeServices
  class Base
    attr_reader :service_name

    # Initialize a fake service
    #
    # @param service_name [String] Name of the service being faked
    def initialize(service_name)
      @service_name = service_name
      log_init
    end

    protected

    # Log a message specific to this service
    #
    # @param message [String] Message to log
    # @param level [Symbol] Log level (:info, :warn, :error, :debug)
    def log(message, level: :info)
      prefix = "[FAKE #{service_name.upcase}]"

      case level
      when :info
        Rails.logger.info "#{prefix} #{message}"
      when :warn
        Rails.logger.warn "#{prefix} #{message}"
      when :error
        Rails.logger.error "#{prefix} #{message}"
      when :debug
        Rails.logger.debug "#{prefix} #{message}"
      end
    end

    # Log initialization message
    def log_init
      log("Initialized (fake mode enabled)", level: :info) if show_warnings?
    end

    # Check if warnings should be shown
    #
    # @return [Boolean] true if warnings are enabled
    def show_warnings?
      ENV['SHOW_FAKE_SERVICE_WARNINGS'] == 'true'
    end

    # Create a fake/mock response object
    #
    # @param attributes [Hash] Attributes for the mock object
    # @return [OpenStruct] Mock response object
    def mock_response(**attributes)
      OpenStruct.new(attributes)
    end

    # Generate a fake ID (useful for mock responses)
    #
    # @param prefix [String] Prefix for the ID
    # @return [String] Fake ID like "FAKE_SMS_a1b2c3d4"
    def fake_id(prefix = 'FAKE')
      "#{prefix}_#{SecureRandom.hex(8)}"
    end

    # Get current timestamp for logging
    #
    # @return [String] Formatted timestamp
    def timestamp
      Time.current.strftime('%Y-%m-%d %H:%M:%S')
    end

    # Append to a log file specific to this service
    #
    # @param message [String] Message to append
    # @param filename [String] Name of the log file (default: service_name.log)
    def append_to_log(message, filename: nil)
      filename ||= "#{service_name.downcase.gsub(' ', '_')}.log"
      log_path = Rails.root.join('log', filename)

      File.open(log_path, 'a') do |file|
        file.puts "[#{timestamp}] #{message}"
      end
    rescue StandardError => e
      log("Failed to write to log file: #{e.message}", level: :error)
    end

    # Read from a data file in db/fake_data/
    #
    # @param filename [String] Name of the file to read
    # @return [String, nil] File contents or nil if not found
    def read_fake_data(filename)
      file_path = Rails.root.join('db', 'fake_data', filename)

      return nil unless File.exist?(file_path)

      File.read(file_path)
    rescue StandardError => e
      log("Failed to read fake data file #{filename}: #{e.message}", level: :error)
      nil
    end

    # Parse YAML data from fake_data directory
    #
    # @param filename [String] Name of the YAML file
    # @return [Hash, Array, nil] Parsed YAML data or nil if not found
    def load_fake_yaml(filename)
      data = read_fake_data(filename)
      return nil unless data

      YAML.safe_load(data, permitted_classes: [Symbol, Date, Time])
    rescue Psych::SyntaxError => e
      log("Failed to parse YAML file #{filename}: #{e.message}", level: :error)
      nil
    end

    # Check if we're in test environment
    #
    # @return [Boolean] true if Rails.env.test?
    def test_environment?
      Rails.env.test?
    end

    # Check if we're in development environment
    #
    # @return [Boolean] true if Rails.env.development?
    def development_environment?
      Rails.env.development?
    end

    # Simulate network delay (useful for realistic testing)
    #
    # @param seconds [Float] Number of seconds to sleep
    def simulate_delay(seconds = 0.5)
      return if test_environment? # Don't delay in tests

      sleep(seconds) if show_warnings?
    end
  end
end
