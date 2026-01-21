Rails.application.config.after_initialize do
  # Determine which geocoder lookup to use (real AWS or fake cached data)
  geocoder_lookup = GeocoderService.lookup

  # Configure Geocoder gem
  Geocoder.configure(
    # Geocoding options
    timeout: 10,                 # geocoding service timeout (secs)
    lookup: geocoder_lookup,     # Determined by GeocoderService (fake or real)

    # AWS Location Service configuration (only used when lookup is :amazon_location_service)
    amazon_location_service: GeocoderService.aws_config
  )

  # Configure AWS SDK (only if using real AWS Location Service)
  unless GeocoderService.use_fake?
    Aws.config.update({region: 'us-west-2'})
  end
end
