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
    this.isLeaflet = false
  }

  // Detect which map library is being used
  _detectMapLibrary(map) {
    // Leaflet maps have _leaflet_id property
    return map && (map._leaflet_id !== undefined || (typeof L !== 'undefined' && map instanceof L.Map))
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
    this.isLeaflet = this._detectMapLibrary(map)

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

    // Remove markers - handle both Google Maps and Leaflet
    if (this.userMarker) {
      if (this.isLeaflet) {
        this.map.removeLayer(this.userMarker)
      } else {
        this.userMarker.setMap(null)
      }
      this.userMarker = null
    }

    if (this.userCircle) {
      if (this.isLeaflet) {
        this.map.removeLayer(this.userCircle)
      } else {
        this.userCircle.setMap(null)
      }
      this.userCircle = null
    }

    if (this.headingLine) {
      if (this.isLeaflet) {
        this.map.removeLayer(this.headingLine)
      } else {
        this.headingLine.setMap(null)
      }
      this.headingLine = null
    }

    if (this.headingArrow && this.isLeaflet) {
      this.map.removeLayer(this.headingArrow)
      this.headingArrow = null
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
      if (this.isLeaflet) {
        this.map.setCenter([lat, lng])
      } else {
        this.map.setCenter(new google.maps.LatLng(lat, lng))
      }
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
    if (this.isLeaflet) {
      this._updateUserMarkerLeaflet(lat, lng, accuracy, heading)
    } else {
      this._updateUserMarkerGoogleMaps(lat, lng, accuracy, heading)
    }
  }

  _updateUserMarkerGoogleMaps(lat, lng, accuracy, heading) {
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

  _updateUserMarkerLeaflet(lat, lng, accuracy, heading) {
    const position = [lat, lng]

    // Create or update accuracy circle (blue circle around user position)
    if (!this.userCircle) {
      this.userCircle = L.circle(position, {
        color: '#4285F4',
        opacity: 0.3,
        weight: 1,
        fillColor: '#4285F4',
        fillOpacity: 0.1,
        radius: accuracy
      }).addTo(this.map)
    } else {
      this.userCircle.setLatLng(position)
      this.userCircle.setRadius(accuracy)
    }

    // Create or update user position marker (blue dot)
    if (!this.userMarker) {
      // Create a custom blue dot marker using divIcon
      const markerElement = L.divIcon({
        className: 'user-location-marker',
        html: `
          <div class="user-dot">
            <div class="user-dot-inner"></div>
          </div>
        `,
        iconSize: [20, 20],
        iconAnchor: [10, 10]
      })

      this.userMarker = L.marker(position, {
        icon: markerElement,
        title: 'Your Location',
        zIndexOffset: 1000
      }).addTo(this.map)
    } else {
      this.userMarker.setLatLng(position)
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
    if (this.isLeaflet) {
      this._updateHeadingIndicatorLeaflet(lat, lng, heading)
    } else {
      this._updateHeadingIndicatorGoogleMaps(lat, lng, heading)
    }
  }

  _updateHeadingIndicatorGoogleMaps(lat, lng, heading) {
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

  _updateHeadingIndicatorLeaflet(lat, lng, heading) {
    // Calculate endpoint for heading line (50 meters in direction of heading)
    const headingEndpoint = this.calculateDestination(lat, lng, heading, 50)

    if (!this.headingLine) {
      this.headingLine = L.polyline([
        [lat, lng],
        [headingEndpoint.lat, headingEndpoint.lng]
      ], {
        color: '#4285F4',
        opacity: 0.8,
        weight: 3
      }).addTo(this.map)

      // Add arrowhead using a custom div marker at the end point
      this._createHeadingArrow(headingEndpoint.lat, headingEndpoint.lng, heading)
    } else {
      this.headingLine.setLatLngs([
        [lat, lng],
        [headingEndpoint.lat, headingEndpoint.lng]
      ])

      // Update arrow position
      if (this.headingArrow) {
        this.headingArrow.setLatLng([headingEndpoint.lat, headingEndpoint.lng])
        this.headingArrow.setRotationAngle(heading)
      } else {
        this._createHeadingArrow(headingEndpoint.lat, headingEndpoint.lng, heading)
      }
    }
  }

  _createHeadingArrow(lat, lng, heading) {
    // Create a custom arrow marker for Leaflet
    const arrowIcon = L.divIcon({
      className: 'heading-arrow-icon',
      html: `
        <svg width="20" height="20" viewBox="0 0 20 20" style="transform: rotate(${heading}deg);">
          <path d="M10 0 L15 10 L10 8 L5 10 Z" fill="#4285F4" stroke="#FFFFFF" stroke-width="1"/>
        </svg>
      `,
      iconSize: [20, 20],
      iconAnchor: [10, 10]
    })

    this.headingArrow = L.marker([lat, lng], {
      icon: arrowIcon,
      zIndexOffset: 999
    }).addTo(this.map)

    // Store rotation angle for updates
    this.headingArrow.setRotationAngle = (angle) => {
      const iconDiv = this.headingArrow.getElement()
      if (iconDiv) {
        const svg = iconDiv.querySelector('svg')
        if (svg) {
          svg.style.transform = `rotate(${angle}deg)`
        }
      }
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
    // If we don't have a map reference yet, grab it from the global
    if (!this.map && window.currentMap) {
      this.setupLocationTracking(window.currentMap)
    }

    if (this.currentPosition) {
      this._centerMapOnPosition(this.currentPosition.lat, this.currentPosition.lng)
    } else {
      // Request location now if not already tracking
      if (!navigator.geolocation) {
        alert('Geolocation is not supported by this browser.')
        return
      }

      // Start tracking if not already
      if (!this.watchId && this.map) {
        this.startTracking()
      }

      // Also do a one-shot request for immediate centering
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const lat = position.coords.latitude
          const lng = position.coords.longitude
          this.currentPosition = { lat, lng }
          this._centerMapOnPosition(lat, lng)
          this.updateUserMarker(lat, lng, position.coords.accuracy, position.coords.heading)
        },
        (error) => {
          if (error.code === error.PERMISSION_DENIED) {
            alert('Location access denied. Please enable location permissions in your browser settings.')
          } else {
            alert('Unable to get your location. Please try again.')
          }
        },
        { enableHighAccuracy: true, timeout: 10000 }
      )
    }
  }

  _centerMapOnPosition(lat, lng) {
    if (this.isLeaflet) {
      this.map.setView([lat, lng], 16)
    } else {
      this.map.setCenter(new google.maps.LatLng(lat, lng))
      this.map.setZoom(16)
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
