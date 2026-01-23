# Map State Persistence

## Overview

This feature maintains the map's position (center coordinates) and zoom level after users perform actions on trees (marking as picked, missing, or submitting donation forms). Previously, the map would reset to default coordinates after these actions.

## Implementation

### Components

1. **Stimulus Controller** (`app/javascript/controllers/map_state_controller.js`)
   - Manages saving and restoring map state using browser SessionStorage
   - Provides methods to save/load map center and zoom level
   - Implements debounced saving to avoid excessive writes
   - Handles edge cases (stale data, missing storage, etc.)

2. **Map Initialization** (`app/views/shared/_map_js.html.erb`)
   - Modified to check for saved state before using defaults
   - Sets up event listeners to save state when map moves or zooms
   - Falls back to route/zone/reservation defaults when no saved state exists

3. **View Templates**
   - `app/views/driver/reservations/map.html.erb` - Attached Stimulus controller with driver-specific storage key
   - `app/views/admin/reservations/map.html.erb` - Attached Stimulus controller with admin-specific storage key

### How It Works

1. **On Page Load:**
   - Stimulus controller connects and checks SessionStorage for saved state
   - If saved state exists and is fresh (< 1 hour old), use it
   - Otherwise, use default coordinates from route/zone/reservation
   - Map initializes with saved or default position

2. **When Map Moves:**
   - Google Maps 'idle' event fires when map stops moving
   - Debounced save function stores center and zoom to SessionStorage
   - Timestamp is added to detect stale data

3. **On User Action (Picked/Missing/Donation):**
   - Turbo intercepts navigation and triggers save
   - Page reloads via Turbo
   - Stimulus controller reconnects and restores saved state

4. **Storage Keys:**
   - Driver maps: `mapState_driver_{route_id|zone_id|reservation_id|'all'}`
   - Admin maps: `mapState_admin_{route_id|zone_id|'all'}`
   - Different routes/zones maintain independent states

### Bug Fixes

- Fixed incorrect URL in admin map (line 80 used `/driver/` instead of `/admin/`)

## Testing

### System Tests

Two comprehensive test suites were added:

1. **Driver Map Tests** (`test/system/driver/map_state_test.rb`)
   - Verifies state persistence after marking trees as picked
   - Verifies state persistence after marking trees as missing
   - Verifies state persistence after donation form submission
   - Tests independent states for different routes
   - Tests state persistence across page refresh
   - Tests default behavior when no saved state exists

2. **Admin Map Tests** (`test/system/admin/map_state_test.rb`)
   - Verifies admin map state persistence
   - Tests separate storage keys for admin vs driver
   - Tests graceful degradation when sessionStorage unavailable

### Running Tests

```bash
# Run all map state tests
rails test test/system/driver/map_state_test.rb
rails test test/system/admin/map_state_test.rb

# Run specific test
rails test test/system/driver/map_state_test.rb:test_name
```

### Manual Testing

1. Visit driver map for a route
2. Pan and zoom to a specific location
3. Click on a tree marker
4. Mark it as picked/missing or submit donation form
5. Verify map maintains the same position and zoom level after page reload

## Browser Compatibility

- Uses SessionStorage (supported in all modern browsers: Chrome, Firefox, Safari, Edge)
- Gracefully degrades if sessionStorage is unavailable
- No breaking changes for browsers with storage disabled

## Future Enhancements

- Remember which info window was open
- Persist map filters/settings
- Option to use LocalStorage for cross-session persistence
- User preference to disable state persistence
- Add visual indicator when state is saved/restored

## Technical Notes

- **SessionStorage** vs **LocalStorage**: SessionStorage was chosen because it:
  - Clears when browser session ends (better for privacy)
  - Is scoped per tab (each tab can have independent state)
  - Doesn't persist indefinitely (prevents stale data accumulation)

- **Debouncing**: Map changes fire frequently during panning/zooming. Saves are debounced to 500ms to reduce storage writes.

- **Stale Data**: Saved states older than 1 hour are automatically discarded to prevent using outdated positions.

- **Global References**: The controller uses `window.mapStateController` and `window.currentMap` for communication between Stimulus and the Google Maps callback. This is necessary because Google Maps initializes via a global callback function.
