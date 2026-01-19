# FAKE SERVICES IMPLEMENTATION PLAN

## Executive Summary

This plan outlines the implementation of fake/stub services for the Tree Recycle application, enabling development and testing without requiring API keys for external services. The goal is to make the application deployable and functional with fake data, while maintaining the ability to easily switch to real services when needed.

## 1. Current External Service Dependencies Analysis

### 1.1 Service Inventory

| Service | Purpose | Usage Location | Required? | Fakeable? |
|---------|---------|----------------|-----------|-----------|
| **Google Maps JavaScript API** | Map display, markers, polygons | Views (admin/driver maps) | Yes (for maps) | Yes (via Leaflet.js) |
| **AWS Location Service** | Address geocoding (address → lat/lng) | `app/models/concerns/geocodable.rb` | Yes | Yes (cached data) |
| **Stripe** | Payment processing | `app/controllers/donations_controller.rb` | No (feature can be disabled) | Yes (test mode) |
| **Twilio** | SMS notifications | `app/models/sms.rb` | No (feature can be disabled) | Yes (logging stub) |
| **USPS API** | Address validation | `app/controllers/reservations_controller.rb` | No (optional) | Yes (cached data) |
| **Gmail SMTP** | Email delivery | ActionMailer | No (test mode exists) | Already handled |

### 1.2 Bainbridge Island, WA Context

The application is designed for Bainbridge Island, WA. Key coordinates:
- **Center**: 47.6426° N, 122.5213° W
- **Bounding Box**:
  - North: 47.73° N
  - South: 47.58° N
  - East: -122.45° W
  - West: -122.58° W

The seeds.rb file already contains 75+ real Bainbridge Island addresses that can be used for fake data.

## 2. Implementation Strategy

### 2.1 Configuration Approach

Create a multi-layer configuration system:

1. **Environment variable**: `FAKE_SERVICES_ENABLED` (true/false)
2. **Per-service toggles**: `FAKE_MAPS`, `FAKE_GEOCODER`, `FAKE_STRIPE`, etc.
3. **Default behavior**: When credentials are missing, automatically use fake services with a warning

### 2.2 Architecture Pattern

Use the **Strategy Pattern** with service adapters:
- Create interface/adapter classes for each service
- Implement both Real and Fake versions
- Use factory pattern to instantiate correct version based on configuration

## 3. Detailed Implementation Plan by Service

### 3.1 Google Maps → OpenStreetMap/Leaflet.js

**Objective**: Replace Google Maps with Leaflet.js + OpenStreetMap for development

**Why Leaflet.js?**
- Free and open source
- No API key required
- Similar feature set (markers, polygons, popups)
- Easy to swap back to Google Maps for production

**Implementation Steps**:

**Step 1**: Create map service adapter
- **File to create**: `app/services/map_service.rb`
- **Purpose**: Abstract map service selection
```ruby
# Pseudocode structure
class MapService
  def self.enabled?
    ENV['FAKE_MAPS'] != 'true' && google_maps_api_key.present?
  end

  def self.google_maps_api_key
    Rails.application.credentials.dig(:google_maps, :api_key)
  rescue
    nil
  end

  def self.use_leaflet?
    !enabled?
  end
end
```

**Step 2**: Create Leaflet.js view partials
- **Files to create**:
  - `app/views/shared/_leaflet_map_js.html.erb` (replacement for `_map_js.html.erb`)
  - `app/views/shared/_leaflet_head.html.erb` (Leaflet CSS/JS includes)

**Step 3**: Modify existing map views to conditionally load Google Maps or Leaflet
- **Files to modify**:
  - `app/views/admin/reservations/map.html.erb`
  - `app/views/driver/reservations/map.html.erb`
  - `app/views/admin/routes/map.html.erb`
  - `app/views/admin/routes/map_all.html.erb`

**Step 4**: Update Stimulus controllers to support both map libraries
- **Files to modify**:
  - `app/javascript/controllers/map_state_controller.js` (add Leaflet support)
  - `app/javascript/controllers/user_location_controller.js` (add Leaflet support)

**Step 5**: Add Leaflet.js to asset pipeline
- **File to modify**: `config/importmap.rb`
- Pin Leaflet.js library

### 3.2 AWS Location Service → Fake Geocoder

**Objective**: Cache geocoding results for Bainbridge Island addresses

**Implementation Steps**:

**Step 1**: Create geocoder service adapter
- **File to create**: `app/services/geocoder_service.rb`
```ruby
# Pseudocode
class GeocoderService
  def self.lookup
    if ENV['FAKE_GEOCODER'] == 'true' || !aws_credentials_present?
      :fake_geocoder
    else
      :amazon_location_service
    end
  end
end
```

**Step 2**: Create fake geocoder lookup plugin
- **File to create**: `lib/geocoder/lookups/fake_geocoder.rb`
- Implements Geocoder gem's lookup interface
- Uses cached data for known Bainbridge addresses
- Returns reasonable defaults for unknown addresses

**Step 3**: Create Bainbridge Island geocoding data cache
- **File to create**: `db/fake_data/bainbridge_geocoding_cache.yml`
- Contains lat/lng for all addresses in seeds.rb
- Generated from existing seed data

**Step 4**: Modify geocoder initializer
- **File to modify**: `config/initializers/geocoder.rb`
- Add fake_geocoder configuration
- Switch lookup based on environment

**Step 5**: Create rake task to populate geocoding cache
- **File to create**: `lib/tasks/fake_services.rake`
- Task: `rake fake_services:generate_geocoding_cache`
- Geocodes all seed addresses once and caches results

### 3.3 Stripe → Test Mode

**Objective**: Use Stripe's built-in test mode

**Implementation Steps**:

**Step 1**: Create Stripe service adapter
- **File to create**: `app/services/stripe_service.rb`
```ruby
# Pseudocode
class StripeService
  def self.fake_mode?
    ENV['FAKE_STRIPE'] == 'true' || test_keys_only?
  end

  def self.publishable_key
    if fake_mode?
      'pk_test_fake_development_key'
    else
      # existing logic
    end
  end
end
```

**Step 2**: Update Stripe initializer
- **File to modify**: `config/initializers/stripe.rb`
- Use StripeService for key selection
- Add fake test keys as fallback

**Step 3**: Document test card numbers
- **File to create**: `doc/FAKE_SERVICES.md`
- List Stripe test card numbers (4242 4242 4242 4242, etc.)

**Note**: Stripe already supports test mode well, minimal work needed.

### 3.4 Twilio → SMS Logger

**Objective**: Log SMS messages instead of sending them

**Implementation Steps**:

**Step 1**: Create SMS service adapter
- **File to create**: `app/services/sms_service.rb`
- Factory pattern for real vs fake SMS

**Step 2**: Create fake SMS client
- **File to create**: `app/services/fake_sms_client.rb`
```ruby
# Pseudocode
class FakeSmsClient
  def messages
    self
  end

  def create(from:, to:, body:)
    # Log to Rails logger
    # Append to fake_sms.log file
    # Return mock response
    OpenStruct.new(sid: "FAKE_#{SecureRandom.hex(8)}", status: 'sent')
  end
end
```

**Step 3**: Modify SMS model
- **File to modify**: `app/models/sms.rb`
- Use SmsService factory to get client
- Check for fake mode

**Step 4**: Create SMS log viewer (optional)
- **File to create**: `app/controllers/admin/fake_sms_controller.rb`
- View all "sent" fake SMS messages
- Admin-only access

### 3.5 USPS API → Cached Validator

**Objective**: Return cached validation results for known addresses

**Implementation Steps**:

**Step 1**: Create USPS service adapter
- **File to create**: `app/services/usps_service.rb`

**Step 2**: Create fake USPS validator
- **File to create**: `app/services/fake_usps_validator.rb`
```ruby
# Pseudocode
class FakeUspsValidator
  def validate(address1:, city:, state:)
    # For Bainbridge Island addresses, return success
    # Parse house number and street name
    # Return formatted address
    # For unknown, return as-is with success
  end
end
```

**Step 3**: Modify reservations controller
- **File to modify**: `app/controllers/reservations_controller.rb`
- Use UspsService in address_verification action

**Step 4**: Create address validation cache
- **File to create**: `db/fake_data/bainbridge_address_validation.yml`
- Validated versions of seed addresses

### 3.6 Gmail SMTP → Already Handled

**Status**: Rails already handles this via `config.action_mailer.delivery_method = :test` in test environment.

**Additional Step**: Create development email preview
- **File to create**: `config/environments/development.rb` modification
- Optional: Use letter_opener gem to preview emails in browser

## 4. Data Fixtures for Bainbridge Island

### 4.1 Geocoding Data

**File to create**: `db/fake_data/bainbridge_geocoding_cache.yml`

Structure:
```yaml
addresses:
  "215 Ericksen Ave NE, Bainbridge Island, WA":
    latitude: 47.62596
    longitude: -122.51753
    house_number: "215"
    street_name: "Ericksen Ave NE"
  # ... 75+ more addresses from seeds.rb
```

### 4.2 Zone/Route Boundaries

**File to create**: `db/fake_data/bainbridge_routes.yml`

Already exists in seeds.rb - extract to YAML for easy reference:
```yaml
zones:
  - name: Center
    coordinates: [47.6426, -122.5213]
  - name: West
    coordinates: [47.6559, -122.5468]
  # ... etc
```

### 4.3 Sample Reservations

**File to enhance**: `test/factories/reservations.rb`

Add more Bainbridge-specific factories:
```ruby
factory :bainbridge_reservation do
  street { FakeBainbridgeData.random_street }
  city { 'Bainbridge Island' }
  state { 'Washington' }
  latitude { FakeBainbridgeData.lat_for_street(street) }
  longitude { FakeBainbridgeData.lng_for_street(street) }
end
```

## 5. Configuration Files

### 5.1 Environment Variables

**File to create**: `.env.example`

```bash
# Fake Services Configuration
FAKE_SERVICES_ENABLED=true

# Individual service toggles (optional - overrides FAKE_SERVICES_ENABLED)
FAKE_MAPS=true           # Use Leaflet.js instead of Google Maps
FAKE_GEOCODER=true       # Use cached geocoding data
FAKE_STRIPE=true         # Use Stripe test mode
FAKE_TWILIO=true         # Log SMS instead of sending
FAKE_USPS=true           # Skip address validation

# Development-specific
SHOW_FAKE_SERVICE_WARNINGS=true  # Show warnings when using fake services
```

### 5.2 Initializer

**File to create**: `config/initializers/fake_services.rb`

```ruby
# Pseudocode
module FakeServices
  def self.enabled?
    ENV['FAKE_SERVICES_ENABLED'] == 'true' || Rails.env.development? || Rails.env.test?
  end

  def self.service_enabled?(service_name)
    env_var = "FAKE_#{service_name.to_s.upcase}"
    if ENV[env_var].present?
      ENV[env_var] == 'true'
    else
      enabled?
    end
  end

  def self.warn(service, message)
    if ENV['SHOW_FAKE_SERVICE_WARNINGS'] == 'true'
      Rails.logger.warn "[FAKE SERVICE: #{service}] #{message}"
    end
  end
end
```

### 5.3 Credentials Handling

**File to modify**: `config/application.rb`

Add fallback for missing credentials:
```ruby
# Allow missing credentials in development/test
config.require_master_key = Rails.env.production?
```

## 6. Step-by-Step Implementation Sequence

### Phase 1: Foundation (Days 1-2)

1. Create `config/initializers/fake_services.rb`
2. Create `.env.example` with fake service flags
3. Add dotenv-rails gem to Gemfile
4. Create `lib/fake_services/` directory structure
5. Create `db/fake_data/` directory
6. Update README with fake services documentation

### Phase 2: Geocoding (Days 3-4)

1. Create `lib/geocoder/lookups/fake_geocoder.rb`
2. Create `db/fake_data/bainbridge_geocoding_cache.yml` from seeds
3. Create `app/services/geocoder_service.rb`
4. Modify `config/initializers/geocoder.rb`
5. Create rake task `fake_services:generate_geocoding_cache`
6. Test with existing reservations

### Phase 3: Maps (Days 5-7)

1. Add Leaflet.js to importmap
2. Create `app/views/shared/_leaflet_map_js.html.erb`
3. Create `app/views/shared/_leaflet_head.html.erb`
4. Create `app/services/map_service.rb`
5. Modify map views to conditionally load Google Maps or Leaflet
6. Update Stimulus controllers for Leaflet compatibility
7. Test all map views (admin/driver)

### Phase 4: External Services (Days 8-9)

1. Create `app/services/stripe_service.rb`
2. Modify `config/initializers/stripe.rb`
3. Create `app/services/sms_service.rb`
4. Create `app/services/fake_sms_client.rb`
5. Modify `app/models/sms.rb`
6. Create `app/services/usps_service.rb`
7. Create `app/services/fake_usps_validator.rb`
8. Modify `app/controllers/reservations_controller.rb`

### Phase 5: Testing & Documentation (Days 10-11)

1. Test complete flow with fake services
2. Test switching between fake and real services
3. Update test suite to use fake services by default
4. Create `doc/FAKE_SERVICES.md` documentation
5. Update README.md with quick start using fake services
6. Create seeds with comprehensive fake data

### Phase 6: Polish & Deploy (Day 12)

1. Add admin UI indicator showing which services are fake
2. Create health check endpoint showing service status
3. Test deployment without any API keys
4. Verify all features work with fake data
5. Document limitations when using fake services

## 7. Files to Create

### Core Infrastructure

1. `config/initializers/fake_services.rb` - Central configuration
2. `.env.example` - Environment variable template
3. `lib/fake_services/base.rb` - Base class for fake services
4. `doc/FAKE_SERVICES.md` - User documentation

### Geocoding

5. `lib/geocoder/lookups/fake_geocoder.rb` - Fake geocoder implementation
6. `app/services/geocoder_service.rb` - Geocoder factory
7. `db/fake_data/bainbridge_geocoding_cache.yml` - Cached coordinates
8. `lib/tasks/fake_services.rake` - Maintenance tasks

### Maps

9. `app/views/shared/_leaflet_map_js.html.erb` - Leaflet map initialization
10. `app/views/shared/_leaflet_head.html.erb` - Leaflet CSS/JS includes
11. `app/services/map_service.rb` - Map service selector
12. `app/javascript/controllers/leaflet_adapter.js` - Leaflet wrapper (optional)

### External Services

13. `app/services/stripe_service.rb` - Stripe factory
14. `app/services/sms_service.rb` - SMS factory
15. `app/services/fake_sms_client.rb` - Fake Twilio client
16. `app/services/usps_service.rb` - USPS factory
17. `app/services/fake_usps_validator.rb` - Fake USPS validator
18. `db/fake_data/bainbridge_address_validation.yml` - Validated addresses

### Testing & Admin

19. `app/controllers/admin/fake_services_controller.rb` - Admin panel for fake services
20. `app/views/admin/fake_services/index.html.haml` - Service status page
21. `test/services/fake_geocoder_test.rb` - Tests for fake geocoder
22. `test/services/fake_sms_client_test.rb` - Tests for fake SMS

## 8. Files to Modify

### Configuration

1. `config/initializers/geocoder.rb` - Add fake geocoder support
2. `config/initializers/stripe.rb` - Use StripeService
3. `config/importmap.rb` - Add Leaflet.js
4. `Gemfile` - Add dotenv-rails
5. `.gitignore` - Add `.env` file

### Models

6. `app/models/sms.rb` - Use SmsService factory
7. `app/models/concerns/geocodable.rb` - Support fake geocoder

### Controllers

8. `app/controllers/reservations_controller.rb` - Use UspsService
9. `app/controllers/donations_controller.rb` - Use StripeService

### Views

10. `app/views/admin/reservations/map.html.erb` - Conditional map loading
11. `app/views/driver/reservations/map.html.erb` - Conditional map loading
12. `app/views/admin/routes/map.html.erb` - Conditional map loading
13. `app/views/admin/routes/map_all.html.erb` - Conditional map loading
14. `app/views/layouts/application.html.haml` - Add fake service indicator
15. `app/views/layouts/admin/admin.html.haml` - Add fake service indicator

### JavaScript

16. `app/javascript/controllers/map_state_controller.js` - Support Leaflet
17. `app/javascript/controllers/user_location_controller.js` - Support Leaflet

### Tests

18. `test/test_helper.rb` - Enable fake services by default
19. `test/factories/reservations.rb` - Add Bainbridge-specific factories

### Documentation

20. `README.md` - Add quick start with fake services section
21. `db/seeds.rb` - Enhance with more comprehensive fake data

## 9. Bainbridge Island Data Extraction

Extract the following from `db/seeds.rb`:

### Addresses (75+ addresses already exist):
```
215 Ericksen Ave NE
1760 Susan Place
14265 Silven Ave NE
2250 Upper Farms Rd NE
# ... all addresses from seeds.rb
```

### Generate geocoding cache by:
1. Running seeds once with real AWS Location Service
2. Capturing all lat/lng results
3. Saving to `bainbridge_geocoding_cache.yml`
4. Using cached data for future fake service usage

## 10. Success Criteria

### Must Have:
- [ ] Application starts without any API keys
- [ ] Maps display using Leaflet.js (no Google Maps key needed)
- [ ] Reservations can be created with Bainbridge Island addresses
- [ ] Addresses are geocoded using cached data
- [ ] Donations redirect to Stripe test mode (no secret key needed)
- [ ] SMS messages are logged (no Twilio account needed)
- [ ] USPS validation is bypassed/cached
- [ ] All tests pass using fake services
- [ ] Seeds can populate database with realistic data

### Should Have:
- [ ] Admin panel shows which services are fake
- [ ] Easy toggle between fake and real services
- [ ] Warning messages when using fake services
- [ ] Documentation for developers on using fake services
- [ ] Health check endpoint showing service status

### Nice to Have:
- [ ] Admin UI to view "sent" fake SMS messages
- [ ] Ability to test real services from admin panel
- [ ] Automatic fallback to fake when real service fails
- [ ] Performance comparison between fake and real services

## 11. Limitations with Fake Services

When deployed with fake services, the following limitations exist:

### Maps (Leaflet.js vs Google Maps):
- ✅ Basic map display works
- ✅ Markers work
- ✅ Polygons work
- ✅ User location tracking works
- ⚠️ Different visual style (OpenStreetMap vs Google)
- ⚠️ Some Google Maps-specific features may not work
- ❌ Advanced marker customization may differ

### Geocoding (Cached vs AWS Location):
- ✅ Known Bainbridge addresses work perfectly
- ⚠️ Unknown addresses return approximate results
- ⚠️ Addresses outside Bainbridge may not geocode accurately
- ❌ Real-time geocoding of new addresses not available

### Stripe (Test Mode vs Production):
- ✅ Full checkout flow works
- ✅ Test card numbers work
- ✅ Webhooks can be tested
- ❌ No real money is processed
- ❌ Production features not available

### Twilio (Logged vs Sent):
- ✅ Application works without errors
- ✅ SMS "sends" are logged
- ❌ No actual SMS messages sent
- ❌ Users won't receive notifications

### USPS (Bypassed vs Real):
- ✅ Address validation doesn't block users
- ⚠️ Invalid addresses may be accepted
- ❌ No real USPS validation

## 12. Migration Path

### For Developers:
1. Clone repo
2. Run `bundle install`
3. Copy `.env.example` to `.env`
4. Set `FAKE_SERVICES_ENABLED=true`
5. Run `rails db:setup`
6. Start developing immediately

### For Production:
1. Keep fake services enabled initially
2. Add Google Maps API key → set `FAKE_MAPS=false`
3. Add AWS credentials → set `FAKE_GEOCODER=false`
4. Add Stripe keys → set `FAKE_STRIPE=false`
5. Add Twilio credentials → set `FAKE_TWILIO=false`
6. Add USPS key → set `FAKE_USPS=false`
7. Eventually set `FAKE_SERVICES_ENABLED=false`

## 13. Additional Considerations

### Leaflet.js vs Google Maps Trade-offs

**Leaflet.js Advantages:**
- No API key required
- No usage limits
- No costs
- Open source
- Large plugin ecosystem

**Leaflet.js Disadvantages:**
- Different API than Google Maps
- May require refactoring existing map code
- Different marker system
- Slightly different features

**Recommendation**: Use Leaflet.js for development, keep Google Maps as optional for production. This provides:
- Free development environment
- Production can use either (user choice)
- No vendor lock-in

### Data Privacy

Fake services with cached data:
- No external API calls for development
- Test data stays local
- Faster development (no API latency)
- Works offline

### Performance

Fake services are typically faster:
- No network calls
- Instant geocoding (cache lookup)
- No rate limiting
- Better for automated testing

---

## Critical Files for Implementation

Based on the analysis above, here are the 5 most critical files for implementing this plan:

1. **`config/initializers/fake_services.rb`** - Central configuration hub that enables/disables fake services across the application and provides the foundation for all fake service functionality.

2. **`lib/geocoder/lookups/fake_geocoder.rb`** - Implements the fake geocoding service using cached Bainbridge Island address data. This is critical because geocoding is core to the application's functionality (address → coordinates → routing).

3. **`app/views/shared/_leaflet_map_js.html.erb`** - Provides map display without Google Maps API key. Maps are essential for both admin and driver workflows, making this a high-priority file.

4. **`app/services/geocoder_service.rb`** - Factory that switches between real (AWS Location Service) and fake geocoding. This abstraction allows seamless toggling between development and production.

5. **`db/fake_data/bainbridge_geocoding_cache.yml`** - Contains the cached geocoding data for all Bainbridge Island addresses. Without this data file, the fake geocoder cannot function properly.

---

## Implementation Notes

This plan enables the Tree Recycle application to:
1. Run without any external API keys for development
2. Use OpenStreetMap/Leaflet.js for map display (free, no API key)
3. Use cached geocoding data for Bainbridge Island addresses
4. Log instead of sending SMS messages
5. Use Stripe test mode for payments
6. Easily toggle between fake and real services

The phased implementation approach allows incremental development and testing, with each phase building on the previous one. The use of service adapters and factory patterns ensures clean separation of concerns and easy switching between fake and real implementations.
