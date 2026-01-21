# Service adapter for geocoding
#
# Determines whether to use real AWS Location Service or fake cached geocoder
# based on FakeServices configuration and credential availability.
#
# Usage:
#   Geocoder.configure(
#     lookup: GeocoderService.lookup,
#     # ...
#   )

class GeocoderService
  # Get the appropriate geocoder lookup to use
  #
  # @return [Symbol] :amazon_location_service or :fake_geocoder
  def self.lookup
    if use_fake?
      FakeServices.info('geocoder', 'Using fake geocoder with cached Bainbridge Island data')
      :fake_geocoder
    else
      :amazon_location_service
    end
  end

  # Check if fake geocoder should be used
  #
  # @return [Boolean] true if fake geocoder should be used
  def self.use_fake?
    # Use fake if explicitly enabled
    return true if FakeServices.service_enabled?(:geocoder)

    # Use fake if AWS credentials not available
    return true unless aws_credentials_available?

    false
  end

  # Check if AWS Location Service credentials are available
  #
  # @return [Boolean] true if AWS credentials are configured
  def self.aws_credentials_available?
    credentials = Rails.application.credentials.dig(:lookups, :amazon_location_service)
    return false unless credentials

    credentials.dig(:access_key_id).present? && credentials.dig(:secret_access_key).present?
  rescue StandardError => e
    Rails.logger.warn "[GeocoderService] Failed to check AWS credentials: #{e.message}"
    false
  end

  # Get AWS configuration for Geocoder gem
  #
  # @return [Hash] AWS configuration hash
  def self.aws_config
    return {} if use_fake?

    credentials = Rails.application.credentials.dig(:lookups, :amazon_location_service)

    {
      index_name: 'tree_recycle',
      api_key: {
        access_key_id: credentials.dig(:access_key_id),
        secret_access_key: credentials.dig(:secret_access_key)
      }
    }
  rescue StandardError => e
    Rails.logger.error "[GeocoderService] Failed to get AWS config: #{e.message}"
    {}
  end

  # Get status string for debugging
  #
  # @return [String] Status description
  def self.status
    if use_fake?
      "Fake (cached data)"
    else
      "Real (AWS Location Service)"
    end
  end
end
