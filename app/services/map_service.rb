# Service adapter for map display
#
# Determines whether to use Google Maps or Leaflet.js/OpenStreetMap
# based on FakeServices configuration and API key availability.
#
# Usage in views:
#   <% if MapService.use_google_maps? %>
#     <!-- Google Maps code -->
#   <% else %>
#     <!-- Leaflet.js code -->
#   <% end %>

class MapService
  # Check if Google Maps should be used
  #
  # @return [Boolean] true if Google Maps should be used
  def self.use_google_maps?
    # Don't use Google Maps if fake maps are explicitly enabled
    return false if FakeServices.service_enabled?(:maps)

    # Use Google Maps if API key is available
    google_maps_api_key.present?
  end

  # Check if Leaflet.js should be used
  #
  # @return [Boolean] true if Leaflet.js should be used
  def self.use_leaflet?
    !use_google_maps?
  end

  # Get Google Maps API key
  #
  # @return [String, nil] API key or nil if not available
  def self.google_maps_api_key
    Rails.application.credentials.dig(:google_maps, :api_key)
  rescue StandardError => e
    Rails.logger.warn "[MapService] Failed to get Google Maps API key: #{e.message}"
    nil
  end

  # Get map provider name for logging/display
  #
  # @return [String] "Google Maps" or "Leaflet.js / OpenStreetMap"
  def self.provider_name
    use_google_maps? ? "Google Maps" : "Leaflet.js / OpenStreetMap"
  end

  # Get status string for debugging
  #
  # @return [String] Status description
  def self.status
    if use_google_maps?
      "Real (Google Maps)"
    else
      "Fake (Leaflet.js / OpenStreetMap)"
    end
  end

  # Log which map provider is being used
  def self.log_provider
    if FakeServices.service_enabled?(:maps)
      FakeServices.info('maps', "Using #{provider_name} (no API key needed)")
    elsif !google_maps_api_key.present?
      FakeServices.warn('maps', "Google Maps API key not found, falling back to #{provider_name}")
    end
  end
end
