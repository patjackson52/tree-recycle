require 'geocoder/lookups/base'
require 'geocoder/results/fake_geocoder'

module Geocoder
  module Lookup
    class FakeGeocoder < Base
      # Bainbridge Island, WA default coordinates
      DEFAULT_LAT = 47.6426
      DEFAULT_LNG = -122.5213

      def name
        "Fake Geocoder (Cached)"
      end

      private

      def results(query)
        # Load cached geocoding data
        cache_data = load_cache

        # Normalize the query
        normalized_query = normalize_address(query.text)

        # Try to find in cache
        if cache_data && cache_data[normalized_query]
          data = cache_data[normalized_query]
          log_hit(normalized_query)
          return [data]
        end

        # Try fuzzy matching for slight variations
        if cache_data
          fuzzy_match = find_fuzzy_match(normalized_query, cache_data)
          if fuzzy_match
            log_fuzzy_hit(normalized_query, fuzzy_match)
            return [cache_data[fuzzy_match]]
          end
        end

        # Not found - return approximate Bainbridge Island location
        log_miss(normalized_query)
        approximate_result(normalized_query)
      end

      def load_cache
        @cache ||= begin
          cache_file = Rails.root.join('db', 'fake_data', 'bainbridge_geocoding_cache.yml')

          unless File.exist?(cache_file)
            Rails.logger.warn "[FakeGeocoder] Cache file not found: #{cache_file}"
            Rails.logger.warn "[FakeGeocoder] Run: rake fake_services:generate_geocoding_cache"
            return {}
          end

          YAML.load_file(cache_file, permitted_classes: [Symbol]) || {}
        rescue StandardError => e
          Rails.logger.error "[FakeGeocoder] Failed to load cache: #{e.message}"
          {}
        end
      end

      # Normalize address for cache lookup
      def normalize_address(address)
        # Remove extra whitespace and convert to lowercase for consistent matching
        normalized = address.to_s.strip.downcase

        # Add "Bainbridge Island, WA" if not present
        unless normalized.include?('bainbridge')
          normalized = "#{normalized}, bainbridge island, wa"
        end

        normalized
      end

      # Try to find a fuzzy match in the cache
      def find_fuzzy_match(query, cache_data)
        # Extract just the street address from the query
        street = query.split(',').first.strip

        # Look for cache entries that start with this street address
        cache_data.keys.find do |cached_address|
          cached_street = cached_address.split(',').first.strip
          cached_street.downcase == street.downcase
        end
      end

      # Return approximate result for unknown addresses
      def approximate_result(query)
        # Generate a slightly randomized position within Bainbridge Island
        # This keeps unknown addresses roughly in the right area
        offset_lat = (rand - 0.5) * 0.02  # ~1 mile variance
        offset_lng = (rand - 0.5) * 0.02

        [{
          'coordinates' => [DEFAULT_LAT + offset_lat, DEFAULT_LNG + offset_lng],
          'address' => query,
          'city' => 'Bainbridge Island',
          'state' => 'Washington',
          'state_code' => 'WA',
          'country' => 'United States',
          'country_code' => 'US',
          'formatted_address' => "#{query}, Bainbridge Island, WA, USA",
          'approximate' => true,
          'fake' => true
        }]
      end

      def log_hit(query)
        Rails.logger.debug "[FakeGeocoder] Cache HIT: #{query}"
      end

      def log_fuzzy_hit(query, matched)
        Rails.logger.debug "[FakeGeocoder] Fuzzy match: '#{query}' -> '#{matched}'"
      end

      def log_miss(query)
        Rails.logger.info "[FakeGeocoder] Cache MISS: #{query} (using approximate location)"
      end

      def check_response_for_errors!(response)
        # Fake geocoder never has errors
      end
    end
  end
end

# Register the fake geocoder lookup
Geocoder::Lookup.register(:fake_geocoder, Geocoder::Lookup::FakeGeocoder)
