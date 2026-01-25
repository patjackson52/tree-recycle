Rails.application.config.after_initialize do
  # Check if AWS credentials are available
  aws_credentials_available = begin
    Rails.application.credentials.dig(:lookups, :amazon_location_service, :access_key_id).present?
  rescue
    false
  end

  if aws_credentials_available
    Geocoder.configure(
      timeout: 10,
      lookup: :amazon_location_service,
      amazon_location_service: {
        index_name: 'tree_recycle',
        api_key: {
          access_key_id: Rails.application.credentials.lookups.amazon_location_service.access_key_id,
          secret_access_key: Rails.application.credentials.lookups.amazon_location_service.secret_access_key
        }
      }
    )
    Aws.config.update({region: 'us-west-2'})
  else
    # Fallback to Nominatim (free, no API key required) when AWS credentials missing
    Rails.logger.warn "AWS Location Service credentials not found, using Nominatim fallback"
    Geocoder.configure(
      timeout: 10,
      lookup: :nominatim
    )
  end
end
