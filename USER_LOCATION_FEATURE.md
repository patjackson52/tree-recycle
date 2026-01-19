# User Location and Heading Feature

## Overview

The map component now displays the user's current location and heading/direction in real-time. This helps drivers navigate to tree pickup locations more efficiently by showing their position on the map.

## Features

### 1. Real-time Location Tracking
- **Geolocation API**: Uses the browser's Geolocation API to continuously track user position
- **Blue Dot Marker**: Shows user's current location with an animated pulsing blue dot
- **Accuracy Circle**: Displays a blue circle around the user showing GPS accuracy radius
- **Auto-updates**: Location updates automatically as the user moves

### 2. Heading/Direction Indicator
- **GPS Heading**: On mobile devices with GPS, shows direction of travel
- **Device Orientation**: On mobile devices, uses compass/gyroscope to show which direction the device is pointing
- **Visual Arrow**: Blue arrow extends from user position showing current heading
- **Platform Support**:
  - iOS: Uses `webkitCompassHeading` for accurate compass bearing
  - Android: Uses `deviceorientation` alpha value
  - Desktop: GPS heading only (when available from high-precision GPS)

### 3. Location Controls
- **Center Button**: Crosshair button in bottom-right corner
- **One-tap Centering**: Click to instantly center map on user's current location
- **Auto-zoom**: Automatically zooms to street level (zoom 18) when centering
- **Visual Feedback**: Button shows active state when location is available

## How It Works

### Location Tracking Flow

1. **Permission Request**: On page load, browser requests location permission
2. **Continuous Watch**: Uses `watchPosition` for real-time updates
3. **High Accuracy**: Configured with `enableHighAccuracy: true` for best precision
4. **Error Handling**: Gracefully handles permission denials and GPS unavailability

### Heading Detection

The system tries multiple methods to determine heading:

1. **GPS Heading**: Primary method - direction of travel from GPS
2. **Device Orientation (Absolute)**: Compass heading on supported devices
3. **Device Orientation (Relative)**: Fallback for devices without compass
4. **Fallback**: If no heading available, only shows position without direction arrow

### Visual Components

**User Location Marker:**
```
┌─────────────┐
│  ⊙  ← Blue  │  Animated pulsing effect
│     Dot     │  White center dot
└─────────────┘
```

**Accuracy Circle:**
- Transparent blue circle
- Radius = GPS accuracy in meters
- Helps users understand location precision

**Heading Arrow:**
- Blue line with arrowhead
- 50 meters long (visual length)
- Points in direction of travel/orientation

## Browser Compatibility

### Desktop Browsers
- ✅ Chrome/Edge: Full support with GPS devices
- ✅ Firefox: Full support with GPS devices
- ✅ Safari: Full support with GPS devices
- ⚠️ Location available only with external GPS or Wi-Fi positioning

### Mobile Browsers
- ✅ iOS Safari: Full support with GPS + compass heading
- ✅ Chrome Android: Full support with GPS + device orientation
- ✅ Firefox Android: Full support with GPS + device orientation
- ⚠️ iOS 13+ requires explicit permission for device orientation

### Permissions Required

**Location Permission:**
- Browser will prompt for location access on first use
- Required for any location features to work
- Can be revoked in browser settings

**Motion/Orientation Permission (iOS 13+):**
- Automatically requested on iOS devices
- Required for compass heading
- Optional - location works without it

## Privacy & Security

### What's Tracked
- ✅ Current GPS coordinates (latitude/longitude)
- ✅ GPS accuracy
- ✅ Device heading/orientation
- ✅ All data stays in browser (SessionStorage only)

### What's NOT Tracked
- ❌ Location history is not stored server-side
- ❌ No location data sent to backend
- ❌ No persistent storage (clears on browser close)
- ❌ No third-party tracking

### User Control
- Users can deny location permission
- Feature degrades gracefully if denied
- Map still shows route/zone locations
- No functionality loss for users who decline

## Technical Implementation

### Files Created/Modified

**New Files:**
- `app/javascript/controllers/user_location_controller.js` - Stimulus controller
- `app/assets/stylesheets/maps.scss` - Map-related styles

**Modified Files:**
- `app/views/shared/_map_js.html.erb` - Added user location setup
- `app/views/driver/reservations/map.html.erb` - Added location button
- `app/views/admin/reservations/map.html.erb` - Added location button
- `app/assets/stylesheets/application.scss` - Import maps.scss

### Key Classes and Methods

**UserLocationController Methods:**

```javascript
setupLocationTracking(map)     // Initialize location tracking
startTracking()                 // Begin GPS watch
stopTracking()                  // Stop GPS watch and cleanup
onLocationUpdate(position)      // Handle GPS position updates
updateUserMarker(...)           // Update blue dot and circle
updateHeadingIndicator(...)     // Update direction arrow
setupOrientationTracking()      // Enable compass/gyroscope
centerOnUser()                  // Center map on user (button action)
```

## Configuration

### Default Settings

```javascript
// Geolocation options
enableHighAccuracy: true    // Use GPS for best accuracy
maximumAge: 10000          // Cache position for max 10 seconds
timeout: 5000              // Timeout after 5 seconds

// Visual settings
markerSize: 20px           // Blue dot diameter
accuracyColor: #4285F4     // Google Maps blue
headingLength: 50m         // Visual length of heading arrow
pulseAnimation: 2s         // Animation cycle duration
```

### Customization

To disable user location on a specific map:

```html
<div id="map"
     data-controller="map-state user-location"
     data-user-location-enabled-value="false">
</div>
```

To center on user automatically on load:

```html
<div id="map"
     data-controller="map-state user-location"
     data-user-location-center-on-location-value="true">
</div>
```

## Usage Guide

### For Drivers

1. **Open map** - Navigate to route map view
2. **Allow location** - Click "Allow" when browser asks for location permission
3. **View position** - Blue pulsing dot shows your current location
4. **See direction** - Blue arrow shows which way you're facing/moving
5. **Center map** - Click crosshair button to center on your location

### Interpreting the Display

- **Large blue circle** = GPS accuracy (smaller = better)
- **Blue dot** = Your exact position
- **Blue arrow** = Direction you're facing/moving
- **Pulsing animation** = Location is actively updating

## Troubleshooting

### Location Not Showing

**Check 1: Location Permission**
- Ensure browser has location permission
- Check browser address bar for location icon
- Reset permission in browser settings if needed

**Check 2: GPS Signal**
- Ensure device has GPS capability
- Move to open area for better GPS signal
- Wait 30-60 seconds for GPS lock

**Check 3: Browser Compatibility**
- Use modern browser (Chrome, Firefox, Safari, Edge)
- Update browser to latest version
- Check console for error messages

### Heading Not Showing

**Issue**: Blue dot shows but no arrow

**Solutions:**
- On mobile: Ensure device has compass/magnetometer
- On iOS 13+: Allow motion/orientation permission
- Start moving - GPS heading requires motion
- Calibrate device compass (figure-8 motion)

### Inaccurate Location

**Symptoms**: Blue circle very large, jumpy position

**Solutions:**
- Move outdoors for better GPS signal
- Wait for GPS to acquire more satellites
- Disable Wi-Fi and use cellular GPS (more accurate)
- Check device GPS is enabled in system settings

### Button Not Working

**Issue**: Clicking crosshair does nothing

**Solutions:**
- Wait for location to be acquired first
- Check browser console for JavaScript errors
- Ensure Stimulus controllers loaded properly
- Verify user-location controller is connected

## Performance Considerations

### Battery Impact
- Continuous GPS tracking uses battery
- Location updates throttled to reduce power usage
- High accuracy mode uses more power
- Consider disabling when not actively navigating

### Data Usage
- Minimal data usage (GPS is device-based)
- Map tiles may use data when panning
- No location data uploaded to server

### Memory Usage
- Lightweight implementation
- Cleans up markers on disconnect
- No memory leaks from event listeners

## Future Enhancements

Potential improvements for future versions:

- [ ] **Navigation Mode**: Route guidance from user location to destination
- [ ] **Speed Display**: Show current travel speed
- [ ] **Altitude**: Display elevation if available
- [ ] **Location History**: Optional breadcrumb trail
- [ ] **Geofencing**: Alerts when near pickup location
- [ ] **Offline Support**: Cache location when offline
- [ ] **Battery Saver**: Reduce GPS frequency when stationary
- [ ] **Manual Location**: Allow manual position override

## Testing

### Manual Testing Checklist

- [ ] Desktop Chrome: Location permission requested
- [ ] Desktop Firefox: Location marker appears
- [ ] Desktop Safari: Center button works
- [ ] Mobile iOS Safari: Heading arrow shows direction
- [ ] Mobile Chrome Android: Compass calibration works
- [ ] Permission denied: Map still functional
- [ ] No GPS device: Graceful degradation
- [ ] Map state persistence: Location doesn't interfere with saved position

### Test Cases

```javascript
// Test 1: Location permission granted
1. Open map
2. Click "Allow" on permission prompt
3. Verify blue dot appears
4. Verify accuracy circle shows

// Test 2: Heading display (mobile)
1. Open map on mobile device
2. Allow location and motion permissions
3. Rotate device
4. Verify blue arrow rotates with device

// Test 3: Center on location
1. Pan map away from user location
2. Click crosshair button
3. Verify map centers on blue dot
4. Verify zoom level increases to 18

// Test 4: Permission denied
1. Open map
2. Click "Block" on permission prompt
3. Verify map still shows route markers
4. Verify no errors in console
5. Verify button is disabled or hidden
```

## Resources

- [Geolocation API MDN Docs](https://developer.mozilla.org/en-US/docs/Web/API/Geolocation_API)
- [Device Orientation API](https://developer.mozilla.org/en-US/docs/Web/API/Device_orientation_events)
- [Google Maps JavaScript API](https://developers.google.com/maps/documentation/javascript)
- [Stimulus Framework](https://stimulus.hotwired.dev/)

## Support

For issues or questions:
1. Check browser console for error messages
2. Verify location permissions are granted
3. Test with different browser/device
4. Review this documentation
5. Report issues on GitHub

---

**Version**: 1.0
**Last Updated**: 2026-01-19
**Compatibility**: Modern browsers with Geolocation API support
