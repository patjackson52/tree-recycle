require 'geocoder/results/base'

module Geocoder
  module Result
    class FakeGeocoder < Base
      def coordinates
        @data['coordinates'] || [DEFAULT_LAT, DEFAULT_LNG]
      end

      def latitude
        coordinates[0]
      end

      def longitude
        coordinates[1]
      end

      def address
        @data['address']
      end

      def city
        @data['city'] || 'Bainbridge Island'
      end

      def state
        @data['state'] || 'Washington'
      end

      def state_code
        @data['state_code'] || 'WA'
      end

      def country
        @data['country'] || 'United States'
      end

      def country_code
        @data['country_code'] || 'US'
      end

      def formatted_address
        @data['formatted_address'] || address
      end

      # Indicate this is an approximate location (for cache misses)
      def approximate?
        @data['approximate'] == true
      end

      # Indicate this came from fake geocoder
      def fake?
        true
      end

      private

      DEFAULT_LAT = 47.6426
      DEFAULT_LNG = -122.5213
    end
  end
end
