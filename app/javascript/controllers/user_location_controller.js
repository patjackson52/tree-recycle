import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    enabled: { type: Boolean, default: true },
    centerOnLocation: { type: Boolean, default: false }
  }

  connect() {
    // Store reference globally so map initialization can access it
    window.userLocationController = this

    this.userMarker = null
    this.userCircle = null
    this.headingLine = null
    this.watchId = null
    this.currentPosition = null
    this.currentHeading = null
  }

  disconnect() {
    this.stopTracking()
    delete window.userLocationController
  }

  // Initialize user location tracking on the map
  setupLocationTracking(map) {
    if (!this.enabledValue) {
      return
    }

    this.map = map

    // Check if geolocation is supported
    if (!navigator.geolocation) {
      console.warn('Geolocation is not supported by this browser')
      return
    }

    // Request location permission and start tracking
    this.startTracking()

    // Also set up device orientation for heading if available
    this.setupOrientationTracking()
  }

  startTracking() {
    const options = {
      enableHighAccuracy: true,
      maximumAge: 10000,
      timeout: 5000
    }

    // Watch position for continuous updates
    this.watchId = navigator.geolocation.watchPosition(
      (position) => this.onLocationUpdate(position),
      (error) => this.onLocationError(error),
      options
    )
  }

  stopTracking() {
    if (this.watchId) {
      navigator.geolocation.clearWatch(this.watchId)
      this.watchId = null
    }

    if (window.DeviceOrientationEvent && this.orientationHandler) {
      window.removeEventListener('deviceorientationabsolute', this.orientationHandler)
      window.removeEventListener('deviceorientation', this.orientationHandler)
    }

    // Remove markers
    if (this.userMarker) {
      this.userMarker.setMap(null)
      this.userMarker = null
    }

    if (this.userCircle) {
      this.userCircle.setMap(null)
      this.userCircle = null
    }

    if (this.headingLine) {
      this.headingLine.setMap(null)
      this.headingLine = null
    }
  }

  onLocationUpdate(position) {
    const lat = position.coords.latitude
    const lng = position.coords.longitude
    const accuracy = position.coords.accuracy
    const heading = position.coords.heading // May be null on desktop

    this.currentPosition = { lat, lng }

    // Update or create user marker
    this.updateUserMarker(lat, lng, accuracy, heading)

    // Center map on user location if enabled
    if (this.centerOnLocationValue) {
      this.map.setCenter(new google.maps.LatLng(lat, lng))
      // Only center once, then disable
      this.centerOnLocationValue = false
    }
  }

  onLocationError(error) {
    console.error('Geolocation error:', error.message)

    switch(error.code) {
      case error.PERMISSION_DENIED:
        console.warn('User denied geolocation permission')
        break
      case error.POSITION_UNAVAILABLE:
        console.warn('Location information unavailable')
        break
      case error.TIMEOUT:
        console.warn('Location request timeout')
        break
    }
  }

  updateUserMarker(lat, lng, accuracy, heading) {
    const position = new google.maps.LatLng(lat, lng)

    // Create or update accuracy circle (blue circle around user position)
    if (!this.userCircle) {
      this.userCircle = new google.maps.Circle({
        strokeColor: '#4285F4',
        strokeOpacity: 0.3,
        strokeWeight: 1,
        fillColor: '#4285F4',
        fillOpacity: 0.1,
        map: this.map,
        center: position,
        radius: accuracy
      })
    } else {
      this.userCircle.setCenter(position)
      this.userCircle.setRadius(accuracy)
    }

    // Create or update user position marker (blue dot)
    if (!this.userMarker) {
      // Create a custom blue dot marker
      const markerElement = document.createElement('div')
      markerElement.className = 'user-location-marker'
      markerElement.innerHTML = `
        <div class="user-dot">
          <div class="user-dot-inner"></div>
        </div>
      `

      this.userMarker = new google.maps.marker.AdvancedMarkerView({
        map: this.map,
        position: position,
        content: markerElement,
        title: 'Your Location',
        zIndex: 1000
      })
    } else {
      this.userMarker.position = position
    }

    // Update heading indicator if heading is available
    if (heading !== null && heading !== undefined && !isNaN(heading)) {
      this.updateHeadingIndicator(lat, lng, heading)
    } else if (this.currentHeading !== null) {
      // Use device orientation heading if GPS heading not available
      this.updateHeadingIndicator(lat, lng, this.currentHeading)
    }
  }

  updateHeadingIndicator(lat, lng, heading) {
    // Calculate endpoint for heading line (50 meters in direction of heading)
    const headingEndpoint = this.calculateDestination(lat, lng, heading, 50)

    if (!this.headingLine) {
      this.headingLine = new google.maps.Polyline({
        path: [
          { lat, lng },
          headingEndpoint
        ],
        geodesic: false,
        strokeColor: '#4285F4',
        strokeOpacity: 0.8,
        strokeWeight: 3,
        map: this.map,
        zIndex: 999,
        icons: [{
          icon: {
            path: google.maps.SymbolPath.FORWARD_CLOSED_ARROW,
            scale: 3,
            fillColor: '#4285F4',
            fillOpacity: 1,
            strokeColor: '#FFFFFF',
            strokeWeight: 1
          },
          offset: '100%'
        }]
      })
    } else {
      this.headingLine.setPath([
        { lat, lng },
        headingEndpoint
      ])
    }
  }

  // Calculate destination point given distance and bearing from start point
  calculateDestination(lat, lng, bearing, distance) {
    const R = 6371000 // Earth's radius in meters
    const δ = distance / R // Angular distance
    const θ = bearing * Math.PI / 180 // Convert to radians

    const φ1 = lat * Math.PI / 180
    const λ1 = lng * Math.PI / 180

    const φ2 = Math.asin(
      Math.sin(φ1) * Math.cos(δ) +
      Math.cos(φ1) * Math.sin(δ) * Math.cos(θ)
    )

    const λ2 = λ1 + Math.atan2(
      Math.sin(θ) * Math.sin(δ) * Math.cos(φ1),
      Math.cos(δ) - Math.sin(φ1) * Math.sin(φ2)
    )

    return {
      lat: φ2 * 180 / Math.PI,
      lng: λ2 * 180 / Math.PI
    }
  }

  setupOrientationTracking() {
    // Only relevant for mobile devices
    if (!window.DeviceOrientationEvent) {
      return
    }

    this.orientationHandler = (event) => {
      // Use webkitCompassHeading for iOS, alpha for Android
      let heading = null

      if (event.webkitCompassHeading !== undefined) {
        // iOS
        heading = event.webkitCompassHeading
      } else if (event.alpha !== null) {
        // Android - alpha gives rotation around z-axis
        // We need to adjust for screen orientation
        heading = 360 - event.alpha
      }

      if (heading !== null) {
        this.currentHeading = heading

        // Update heading indicator if we have a position
        if (this.currentPosition) {
          this.updateHeadingIndicator(
            this.currentPosition.lat,
            this.currentPosition.lng,
            heading
          )
        }
      }
    }

    // Try to use deviceorientationabsolute if available (provides compass heading)
    if ('ondeviceorientationabsolute' in window) {
      window.addEventListener('deviceorientationabsolute', this.orientationHandler, true)
    } else if ('ondeviceorientation' in window) {
      window.addEventListener('deviceorientation', this.orientationHandler, true)
    }

    // Request permission for iOS 13+
    if (typeof DeviceOrientationEvent !== 'undefined' &&
        typeof DeviceOrientationEvent.requestPermission === 'function') {
      DeviceOrientationEvent.requestPermission()
        .then(permissionState => {
          if (permissionState === 'granted') {
            window.addEventListener('deviceorientationabsolute', this.orientationHandler, true)
          }
        })
        .catch(console.error)
    }
  }

  // Action to center map on user's current location
  centerOnUser() {
    if (this.currentPosition) {
      this.map.setCenter(new google.maps.LatLng(
        this.currentPosition.lat,
        this.currentPosition.lng
      ))
      this.map.setZoom(18) // Zoom in when centering on user
    } else {
      console.warn('User location not yet available')
    }
  }

  // Toggle location tracking
  toggleTracking() {
    if (this.watchId) {
      this.stopTracking()
    } else {
      this.startTracking()
    }
  }
}
