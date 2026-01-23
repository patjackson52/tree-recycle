namespace :fake_services do
  desc "Generate geocoding cache from seeds.rb addresses"
  task generate_geocoding_cache: :environment do
    puts "=" * 70
    puts "GENERATING GEOCODING CACHE"
    puts "=" * 70
    puts

    # Check if AWS credentials are available
    unless GeocoderService.aws_credentials_available?
      puts "❌ ERROR: AWS Location Service credentials not found!"
      puts
      puts "This task requires real AWS credentials to geocode addresses."
      puts "Add AWS credentials to Rails credentials:"
      puts "  rails credentials:edit"
      puts
      puts "Then add:"
      puts "  lookups:"
      puts "    amazon_location_service:"
      puts "      access_key_id: YOUR_ACCESS_KEY"
      puts "      secret_access_key: YOUR_SECRET_KEY"
      puts
      puts "Or set environment variables:"
      puts "  AWS_ACCESS_KEY_ID=xxx"
      puts "  AWS_SECRET_ACCESS_KEY=xxx"
      puts
      exit 1
    end

    # Temporarily disable fake geocoder to use real AWS
    original_env = ENV['FAKE_GEOCODER']
    ENV['FAKE_GEOCODER'] = 'false'

    begin
      # Reload Geocoder configuration with real AWS
      load Rails.root.join('config/initializers/geocoder.rb')

      puts "Using AWS Location Service for geocoding..."
      puts

      # Extract all addresses from seeds.rb
      addresses = extract_addresses_from_seeds

      puts "Found #{addresses.length} addresses to geocode"
      puts

      # Geocode each address
      cache_data = {}
      success_count = 0
      error_count = 0

      addresses.each_with_index do |address, index|
        print "[#{index + 1}/#{addresses.length}] Geocoding: #{address}..."

        begin
          # Geocode the address
          results = Geocoder.search(address)

          if results.empty?
            puts " ❌ No results"
            error_count += 1
            next
          end

          result = results.first
          normalized_key = normalize_address_key(address)

          cache_data[normalized_key] = {
            'coordinates' => [result.latitude, result.longitude],
            'address' => address,
            'city' => result.city || 'Bainbridge Island',
            'state' => result.state || 'Washington',
            'state_code' => result.state_code || 'WA',
            'country' => result.country || 'United States',
            'country_code' => result.country_code || 'US',
            'formatted_address' => result.formatted_address || address
          }

          puts " ✓ [#{result.latitude}, #{result.longitude}]"
          success_count += 1

          # Rate limiting - be nice to AWS API
          sleep 0.5

        rescue StandardError => e
          puts " ❌ Error: #{e.message}"
          error_count += 1
        end
      end

      # Save to YAML file
      cache_file = Rails.root.join('db', 'fake_data', 'bainbridge_geocoding_cache.yml')

      puts
      puts "Saving cache to: #{cache_file}"

      File.open(cache_file, 'w') do |file|
        file.write("# Geocoding cache for Bainbridge Island addresses\n")
        file.write("# Generated: #{Time.current}\n")
        file.write("# Total addresses: #{cache_data.length}\n")
        file.write("#\n")
        file.write("# This file enables fake geocoder to work without AWS Location Service\n")
        file.write("# Addresses are normalized to lowercase for consistent matching\n\n")
        file.write(cache_data.to_yaml)
      end

      puts
      puts "=" * 70
      puts "GEOCODING CACHE GENERATION COMPLETE"
      puts "=" * 70
      puts "✓ Successfully geocoded: #{success_count} addresses"
      puts "❌ Failed: #{error_count} addresses" if error_count > 0
      puts
      puts "Cache file: #{cache_file}"
      puts "File size: #{File.size(cache_file)} bytes"
      puts
      puts "You can now use fake geocoder by setting:"
      puts "  FAKE_GEOCODER=true"
      puts
    ensure
      # Restore original environment
      ENV['FAKE_GEOCODER'] = original_env
    end
  end

  desc "Show fake services status"
  task status: :environment do
    puts "=" * 70
    puts "FAKE SERVICES STATUS"
    puts "=" * 70
    puts "Global enabled: #{FakeServices.enabled?}"
    puts
    puts "Individual services:"
    FakeServices.status.each do |service, state|
      puts "  #{service.to_s.ljust(15)}: #{state}"
    end
    puts
    puts "Service availability:"
    puts "  Google Maps   : #{FakeServices.google_maps_available? ? '✓ Available' : '✗ Not available'}"
    puts "  AWS Location  : #{FakeServices.aws_location_available? ? '✓ Available' : '✗ Not available'}"
    puts "  Stripe        : #{FakeServices.stripe_available? ? '✓ Available' : '✗ Not available'}"
    puts "  Twilio        : #{FakeServices.twilio_available? ? '✓ Available' : '✗ Not available'}"
    puts "  USPS          : #{FakeServices.usps_available? ? '✓ Available' : '✗ Not available'}"
    puts "=" * 70
  end

  desc "Check geocoding cache status"
  task geocoding_cache_status: :environment do
    cache_file = Rails.root.join('db', 'fake_data', 'bainbridge_geocoding_cache.yml')

    puts "=" * 70
    puts "GEOCODING CACHE STATUS"
    puts "=" * 70

    if File.exist?(cache_file)
      cache_data = YAML.load_file(cache_file, permitted_classes: [Symbol])
      addresses_count = cache_data.is_a?(Hash) ? cache_data.keys.length : 0

      puts "✓ Cache file exists"
      puts "  Location: #{cache_file}"
      puts "  Size: #{File.size(cache_file)} bytes"
      puts "  Addresses: #{addresses_count}"
      puts "  Last modified: #{File.mtime(cache_file)}"
      puts

      if addresses_count > 0
        puts "Sample addresses (first 5):"
        cache_data.keys.first(5).each do |address|
          coords = cache_data[address]['coordinates']
          puts "  • #{address}"
          puts "    → [#{coords[0]}, #{coords[1]}]"
        end
      end
    else
      puts "❌ Cache file not found"
      puts "  Expected location: #{cache_file}"
      puts
      puts "To generate the cache, run:"
      puts "  rake fake_services:generate_geocoding_cache"
    end
    puts "=" * 70
  end

  private

  def extract_addresses_from_seeds
    # Read seeds.rb and extract addresses
    # This is a simplified version - adjust based on actual seeds structure

    addresses = []

    # Zone addresses
    zone_addresses = [
      "7729 Finch Rd NE, Bainbridge Island, WA",
      "5685 NE Wild Cherry Ln, Bainbridge Island, WA",
      "8792 NE Oddfellows Rd, Bainbridge Island, WA",
      "10215 Manitou Beach Dr NE, Bainbridge Island, WA"
    ]
    addresses.concat(zone_addresses)

    # Route addresses
    route_addresses = [
      "9091 Olympus Beach Rd NE, Bainbridge Island, WA",
      "16253 Agate Point Rd NE, Bainbridge Island, WA",
      "10837 Bill Point Bluff NE, Bainbridge Island, WA",
      "1017 Aaron Ave NE, Bainbridge Island, WA",
      "1747 Parade Grounds Ave NE, Bainbridge Island, WA",
      "9458 Capstan Dr NE, Bainbridge Island, WA",
      "8458 NE Meadowmeer Dr, Bainbridge Island, WA",
      "8245 New Holland Ct, Bainbridge Island, WA",
      "3154 Point White Dr NE, Bainbridge Island, WA",
      "4699 NE Mill Heights Cir, Bainbridge Island, WA",
      "10799 Manitou Beach Dr NE, Bainbridge Island, WA",
      "8477 Ferncliff Ave NE, Bainbridge Island, WA",
      "657 Annie Rose Ln NW, Bainbridge Island, WA",
      "400 Harborview Dr SE, Bainbridge Island, WA"
    ]
    addresses.concat(route_addresses)

    # Street addresses (sample subset)
    street_addresses = [
      "215 Ericksen Ave NE, Bainbridge Island, WA",
      "1760 Susan Place, Bainbridge Island, WA",
      "14265 Silven Ave NE, Bainbridge Island, WA",
      "2250 Upper Farms Rd NE, Bainbridge Island, WA",
      "4178 El Cimo Ln NE, Bainbridge Island, WA",
      "7501 NE West Port Madison Rd, Bainbridge Island, WA",
      "786 Fairview Ave NE, Bainbridge Island, WA",
      "4932 McDonald Ave NE, Bainbridge Island, WA",
      "8023 NE Hidden Cove Rd, Bainbridge Island, WA",
      "14100 N Madison Ave NE, Bainbridge Island, WA",
      "9733 NE Sunny Hill Cir, Bainbridge Island, WA",
      "6619 Crystal Springs Dr NE, Bainbridge Island, WA",
      "3083 Point White Dr NE, Bainbridge Island, WA",
      "9596 Green Spot Pl NE, Bainbridge Island, WA"
    ]
    addresses.concat(street_addresses)

    addresses.uniq
  end

  def normalize_address_key(address)
    # Normalize address to match fake geocoder lookup format
    address.strip.downcase
  end
end
