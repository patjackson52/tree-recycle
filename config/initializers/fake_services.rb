# Fake Services Configuration
#
# This module provides a centralized way to enable/disable fake services
# for development and testing without requiring real API keys.
#
# Environment Variables:
# - FAKE_SERVICES_ENABLED: Master toggle for all fake services
# - FAKE_MAPS: Use Leaflet.js instead of Google Maps
# - FAKE_GEOCODER: Use cached geocoding data instead of AWS Location Service
# - FAKE_STRIPE: Use Stripe test mode
# - FAKE_TWILIO: Log SMS instead of sending via Twilio
# - FAKE_USPS: Skip USPS address validation
# - SHOW_FAKE_SERVICE_WARNINGS: Show warnings when using fake services

module FakeServices
  # Check if fake services are globally enabled
  # Defaults to true in development/test, false in production
  def self.enabled?
    if ENV['FAKE_SERVICES_ENABLED'].present?
      ENV['FAKE_SERVICES_ENABLED'] == 'true'
    else
      Rails.env.development? || Rails.env.test?
    end
  end

  # Check if a specific fake service is enabled
  # Individual service flags override the global FAKE_SERVICES_ENABLED setting
  #
  # @param service_name [String, Symbol] Name of the service (e.g., :maps, :geocoder)
  # @return [Boolean] true if the fake version of this service should be used
  def self.service_enabled?(service_name)
    env_var = "FAKE_#{service_name.to_s.upcase}"

    if ENV[env_var].present?
      ENV[env_var] == 'true'
    else
      enabled?
    end
  end

  # Log a warning message about fake service usage
  # Only shows if SHOW_FAKE_SERVICE_WARNINGS is true
  #
  # @param service [String] Name of the service
  # @param message [String] Warning message
  def self.warn(service, message)
    if ENV['SHOW_FAKE_SERVICE_WARNINGS'] == 'true'
      Rails.logger.warn "[FAKE SERVICE: #{service.upcase}] #{message}"
    end
  end

  # Log an info message about fake service usage
  # Only shows if SHOW_FAKE_SERVICE_WARNINGS is true
  #
  # @param service [String] Name of the service
  # @param message [String] Info message
  def self.info(service, message)
    if ENV['SHOW_FAKE_SERVICE_WARNINGS'] == 'true'
      Rails.logger.info "[FAKE SERVICE: #{service.upcase}] #{message}"
    end
  end

  # Check if Google Maps API key is available
  #
  # @return [Boolean] true if Google Maps credentials are configured
  def self.google_maps_available?
    Rails.application.credentials.dig(:google_maps, :api_key).present?
  rescue
    false
  end

  # Check if AWS Location Service credentials are available
  #
  # @return [Boolean] true if AWS credentials are configured
  def self.aws_location_available?
    credentials = Rails.application.credentials.dig(:lookups, :amazon_location_service)
    credentials&.dig(:access_key_id).present? && credentials&.dig(:secret_access_key).present?
  rescue
    false
  end

  # Check if Stripe credentials are available
  #
  # @return [Boolean] true if Stripe credentials are configured
  def self.stripe_available?
    Rails.application.credentials.dig(:stripe, :production, :secret_key).present?
  rescue
    false
  end

  # Check if Twilio credentials are available
  #
  # @return [Boolean] true if Twilio credentials are configured
  def self.twilio_available?
    credentials = Rails.application.credentials.dig(:twilio, :production)
    credentials&.dig(:account_sid).present? && credentials&.dig(:auth_token).present?
  rescue
    false
  end

  # Check if USPS credentials are available
  #
  # @return [Boolean] true if USPS credentials are configured
  def self.usps_available?
    Rails.application.credentials.dig(:usps, :username).present?
  rescue
    false
  end

  # Get a summary of which services are using fake implementations
  #
  # @return [Hash] Service names mapped to their status (real or fake)
  def self.status
    {
      maps: service_enabled?(:maps) ? 'fake (Leaflet.js)' : 'real (Google Maps)',
      geocoder: service_enabled?(:geocoder) ? 'fake (cached)' : 'real (AWS Location)',
      stripe: service_enabled?(:stripe) ? 'fake (test mode)' : 'real',
      twilio: service_enabled?(:twilio) ? 'fake (logged)' : 'real',
      usps: service_enabled?(:usps) ? 'fake (bypassed)' : 'real'
    }
  end

  # Print status to console (useful for debugging)
  def self.print_status
    Rails.logger.info "=" * 60
    Rails.logger.info "FAKE SERVICES STATUS"
    Rails.logger.info "=" * 60
    Rails.logger.info "Global fake services: #{enabled? ? 'ENABLED' : 'DISABLED'}"
    Rails.logger.info "-" * 60
    status.each do |service, state|
      Rails.logger.info "  #{service.to_s.ljust(15)}: #{state}"
    end
    Rails.logger.info "=" * 60
  end
end

# Print status on Rails startup if warnings are enabled
if ENV['SHOW_FAKE_SERVICE_WARNINGS'] == 'true' && defined?(Rails::Server)
  Rails.application.config.after_initialize do
    FakeServices.print_status
  end
end
